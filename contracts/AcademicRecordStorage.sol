// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract AcademicRegistry {
    event InstitutionAdded(address indexed institutionAddress, string name);
    event CourseAdded(address indexed institutionAddress, string courseCode);
    event DisciplineAdded(string courseCode, string disciplineCode);
    event StudentAdded(address indexed studentAddress);
    event GradeAdded(
        address indexed studentAddress,
        string disciplineCode,
        uint16 year,
        uint8 semester
    );
    event AllowedAddressAdded(
        address indexed studentAddress,
        address allowedAddress
    );
    event StudentInformationAdded(address indexed studentAddress);

    address private immutable contractOwner;
    address[] private institutionAddressList;
    mapping(address => bool) public isInstitution;

    struct Institution {
        address institutionAddress;
        string name;
        string document;
        string publicKey;
    }

    struct Course {
        string code;
        string name;
        string courseType;
        int numberOfSemesters;
    }

    struct Discipline {
        string code;
        string name;
        string syllabus;
        int workload;
        int creditCount;
    }

    struct Student {
        address studentAddress;
        string selfEncryptedInformation;
        string institutionEncryptedInformation;
        string publicKey;
        string publicHash;
    }

    struct Grade {
        string disciplineCode;
        uint8 semester;
        uint16 year;
        uint8 grade;
        uint8 attendance;
        bool status;
    }

    mapping(address => Institution) private institutions;
    mapping(address => Course[]) private courses;
    mapping(address => Student) private students;
    mapping(address => Grade[]) private grades;
    mapping(bytes32 => mapping(bytes32 => bool))
        private disciplineExistsInCourse;
    mapping(bytes32 => Discipline[]) private disciplinesByCourse;
    mapping(address => mapping(bytes32 => bool)) private enrollments;
    mapping(address => mapping(address => string)) private recipientEncryptKey;
    mapping(address => mapping(address => string)) private studentInfoRecipient;
    mapping(address => address) private studentToInstitution;
    mapping(address => string) private studentToCourse;

    modifier onlyOwner() {
        require(
            msg.sender == contractOwner,
            "Only the contract owner can perform this action!"
        );
        _;
    }

    modifier onlyInstitution() {
        require(
            isInstitution[msg.sender],
            "Caller is not a registered institution!"
        );
        _;
    }

    modifier onlyStudent(address studentAddress) {
        require(
            msg.sender == studentAddress,
            "Only the student can perform this action!"
        );
        _;
    }

    modifier institutionExists(address institutionAddress) {
        require(
            institutions[institutionAddress].institutionAddress != address(0),
            "Institution is not registered!"
        );
        _;
    }

    modifier studentExists(address studentAddress) {
        require(
            students[studentAddress].studentAddress != address(0),
            "Student is not registered!"
        );
        _;
    }

    modifier studentIsInstitution(
        address studentAddress,
        address institutionAddress
    ) {
        require(
            studentToInstitution[studentAddress] == institutionAddress,
            "Student is not in this Institution!"
        );
        _;
    }

    modifier courseExists(
        address _institutionAddress,
        string memory _courseCode
    ) {
        bool exists = false;
        Course[] storage institutionCourses = courses[_institutionAddress];
        for (uint256 i = 0; i < institutionCourses.length; i++) {
            if (
                keccak256(abi.encodePacked(institutionCourses[i].code)) ==
                keccak256(abi.encodePacked(_courseCode))
            ) {
                exists = true;
                break;
            }
        }
        require(exists, "Course not found!");
        _;
    }

    modifier disciplineExists(bytes32 _courseHash, bytes32 _disciplineHash) {
        require(
            disciplineExistsInCourse[_courseHash][_disciplineHash],
            "Discipline not found in this course!"
        );
        _;
    }

    constructor() {
        contractOwner = msg.sender;
    }

    function addInstitution(
        address _institutionAddress,
        string calldata _name,
        string calldata _document
    ) public onlyOwner {
        require(
            institutions[_institutionAddress].institutionAddress == address(0),
            "Institution already registered!"
        );
        institutions[_institutionAddress] = Institution(
            _institutionAddress,
            _name,
            _document,
            ""
        );
        institutionAddressList.push(_institutionAddress);
        isInstitution[_institutionAddress] = true;
        emit InstitutionAdded(_institutionAddress, _name);
    }

    function addInstitutionPublicKey(
        address _institutionAddress,
        string calldata _publicKey
    ) public onlyInstitution {
        require(
            msg.sender == _institutionAddress,
            "Only the institution itself can add its public key!"
        );
        institutions[_institutionAddress].publicKey = _publicKey;
    }

    function getInstitution(
        address _institutionAddress
    ) public view returns (Institution memory) {
        return institutions[_institutionAddress];
    }

    function getInstitutionList() public view returns (address[] memory) {
        return institutionAddressList;
    }

    function addCourse(
        address _institutionAddress,
        string calldata _code,
        string calldata _name,
        string calldata _courseType,
        int _numberOfSemesters
    ) public institutionExists(_institutionAddress) onlyInstitution {
        require(
            msg.sender == _institutionAddress,
            "Only the specified institution can add courses to itself."
        );
        Course[] storage institutionCourses = courses[_institutionAddress];
        for (uint256 i = 0; i < institutionCourses.length; i++) {
            require(
                keccak256(abi.encodePacked(institutionCourses[i].code)) !=
                    keccak256(abi.encodePacked(_code)),
                "Course already registered!"
            );
        }
        courses[_institutionAddress].push(
            Course(_code, _name, _courseType, _numberOfSemesters)
        );
        emit CourseAdded(_institutionAddress, _code);
    }

    function addDisciplineToCourse(
        address _institutionAddress,
        string calldata _courseCode,
        string calldata _disciplineCode,
        string calldata _name,
        string calldata _syllabus,
        int _workload,
        int _creditCount
    )
        public
        institutionExists(_institutionAddress)
        courseExists(_institutionAddress, _courseCode)
        onlyInstitution
    {
        require(
            msg.sender == _institutionAddress,
            "Only the specified institution can add disciplines to its courses."
        );
        bytes32 courseHash = keccak256(abi.encodePacked(_courseCode));
        bytes32 disciplineHash = keccak256(abi.encodePacked(_disciplineCode));
        require(
            !disciplineExistsInCourse[courseHash][disciplineHash],
            "Discipline already registered in this course!"
        );
        disciplinesByCourse[courseHash].push(
            Discipline(
                _disciplineCode,
                _name,
                _syllabus,
                _workload,
                _creditCount
            )
        );
        disciplineExistsInCourse[courseHash][disciplineHash] = true;
        emit DisciplineAdded(_courseCode, _disciplineCode);
    }

    function addStudent(
        address _institutionAddress,
        address _studentAddress
    ) public institutionExists(_institutionAddress) onlyInstitution {
        require(
            msg.sender == _institutionAddress,
            "Only the specified institution can add students to itself."
        );
        require(
            students[_studentAddress].studentAddress == address(0),
            "Student already registered!"
        );
        students[_studentAddress] = Student(_studentAddress, "", "", "", "");
        studentToInstitution[_studentAddress] = _institutionAddress;
        emit StudentAdded(_studentAddress);
    }

    function getStudent(
        address _studentAddress
    ) public view returns (Student memory) {
        return students[_studentAddress];
    }

    function addGrade(
        address _institutionAddress,
        address _studentAddress,
        string calldata _courseCode,
        string calldata _disciplineCode,
        uint8 _semester,
        uint16 _year,
        uint8 _grade,
        uint8 _attendance,
        bool _status
    )
        public
        institutionExists(_institutionAddress)
        onlyInstitution
        studentExists(_studentAddress)
    {
        require(
            msg.sender == _institutionAddress,
            "Only the specified institution can add grades."
        );
        bytes32 courseHash = keccak256(abi.encodePacked(_courseCode));
        bytes32 disciplineHash = keccak256(abi.encodePacked(_disciplineCode));
        require(
            disciplineExistsInCourse[courseHash][disciplineHash],
            "Discipline not found in this course!"
        );
        if (bytes(studentToCourse[_studentAddress]).length == 0) {
            studentToCourse[_studentAddress] = _courseCode;
        }
        Grade[] storage studentGrades = grades[_studentAddress];
        for (uint256 i = 0; i < studentGrades.length; i++) {
            require(
                !(keccak256(
                    abi.encodePacked(studentGrades[i].disciplineCode)
                ) ==
                    keccak256(abi.encodePacked(_disciplineCode)) &&
                    studentGrades[i].semester == _semester &&
                    studentGrades[i].year == _year),
                "Grade already recorded for this discipline, semester and year!"
            );
        }
        grades[_studentAddress].push(
            Grade(
                _disciplineCode,
                _semester,
                _year,
                _grade,
                _attendance,
                _status
            )
        );
        emit GradeAdded(_studentAddress, _disciplineCode, _year, _semester);
    }

    function addBatchGrades(
        address _institutionAddress,
        address[] calldata _studentAddresses,
        string[] calldata _courseCodes,
        string[] calldata _disciplineCodes,
        uint8[] calldata _semesters,
        uint16[] calldata _years,
        uint8[] calldata _grades,
        uint8[] calldata _attendances,
        bool[] calldata _statuses
    ) public institutionExists(_institutionAddress) onlyInstitution {
        require(
            msg.sender == _institutionAddress,
            "Only the specified institution can add grades in batch."
        );
        uint256 len = _studentAddresses.length;
        require(len > 0, "No grades to register in batch.");
        require(
            len == _courseCodes.length &&
                len == _disciplineCodes.length &&
                len == _semesters.length &&
                len == _years.length &&
                len == _grades.length &&
                len == _attendances.length &&
                len == _statuses.length,
            "All input arrays must have the same length."
        );
        for (uint256 i = 0; i < len; i++) {
            address currentStudentAddress = _studentAddresses[i];
            string memory currentCourseCode = _courseCodes[i];
            string memory currentDisciplineCode = _disciplineCodes[i];
            uint8 currentSemester = _semesters[i];
            uint16 currentYear = _years[i];
            uint8 currentGrade = _grades[i];
            uint8 currentAttendance = _attendances[i];
            bool currentStatus = _statuses[i];

            require(
                students[currentStudentAddress].studentAddress != address(0),
                "Student not registered!"
            );
            bytes32 courseHash = keccak256(abi.encodePacked(currentCourseCode));
            bytes32 disciplineHash = keccak256(
                abi.encodePacked(currentDisciplineCode)
            );

            require(
                disciplineExistsInCourse[courseHash][disciplineHash],
                "Discipline not found in this course!"
            );
            if (bytes(studentToCourse[currentStudentAddress]).length == 0) {
                studentToCourse[currentStudentAddress] = currentCourseCode;
            }

            Grade[] storage studentGrades = grades[currentStudentAddress];
            for (uint256 j = 0; j < studentGrades.length; j++) {
                require(
                    !(keccak256(
                        abi.encodePacked(studentGrades[j].disciplineCode)
                    ) ==
                        keccak256(abi.encodePacked(currentDisciplineCode)) &&
                        studentGrades[j].semester == currentSemester &&
                        studentGrades[j].year == currentYear),
                    "Duplicate grade found for student, discipline, semester and year!"
                );
            }
            grades[currentStudentAddress].push(
                Grade(
                    currentDisciplineCode,
                    currentSemester,
                    currentYear,
                    currentGrade,
                    currentAttendance,
                    currentStatus
                )
            );
            emit GradeAdded(
                currentStudentAddress,
                currentDisciplineCode,
                currentYear,
                currentSemester
            );
        }
    }

    function retrieveRecipientEncrpytKey(
        address _allowedAddress,
        address _studentAddress
    )
        public
        view
        studentExists(_studentAddress)
        onlyStudent(_studentAddress)
        returns (string memory)
    {
        require(
            bytes(recipientEncryptKey[_studentAddress][_allowedAddress])
                .length != 0,
            "Recipient's Key was not shared yet!"
        );
        return recipientEncryptKey[_studentAddress][_allowedAddress];
    }

    function addEncryptedInfoWithRecipientKey(
        address _allowedAddress,
        address _studentAddress,
        string calldata _encryptedData
    ) public studentExists(_studentAddress) onlyStudent(_studentAddress) {
        studentInfoRecipient[_studentAddress][_allowedAddress] = _encryptedData;
    }

    function getEncryptedInfoWithRecipientKey(
        address _allowedAddress,
        address _studentAddress
    ) public view studentExists(_studentAddress) returns (string memory) {
        return studentInfoRecipient[_studentAddress][_allowedAddress];
    }

    function addStudentInformation(
        string calldata _encryptedInformation,
        string calldata _publicKey,
        string calldata _publicHash
    ) public onlyStudent(msg.sender) studentExists(msg.sender) {
        students[msg.sender]
            .institutionEncryptedInformation = _encryptedInformation;
        students[msg.sender].publicKey = _publicKey;
        students[msg.sender].publicHash = _publicHash;
        emit StudentInformationAdded(msg.sender);
    }

    function confirmStudentInformation(
        address _studentAddress,
        address _institutionAddress,
        string calldata _encryptedInformation
    )
        public
        onlyInstitution
        studentExists(_studentAddress)
        studentIsInstitution(_studentAddress, _institutionAddress)
    {
        require(
            msg.sender == _institutionAddress,
            "Only the specified institution can confirm student information."
        );
        students[_studentAddress]
            .selfEncryptedInformation = _encryptedInformation;
    }

    function getPermission() public view returns (string memory) {
        if (msg.sender == contractOwner) {
            return "owner";
        }
        if (students[msg.sender].studentAddress != address(0)) {
            return "student";
        }
        if (isInstitution[msg.sender]) {
            return "institution";
        }
        return "viewer";
    }

    function getStudentInstitutionData(
        address _studentAddress
    )
        public
        view
        returns (Institution memory institution, Course memory course)
    {
        string memory courseCode = studentToCourse[_studentAddress];
        require(
            bytes(courseCode).length > 0,
            "Student not enrolled in any course or no course associated!"
        );

        address institutionAddress = studentToInstitution[_studentAddress];
        require(
            institutionAddress != address(0),
            "Student not associated with any institution!"
        );
        Course[] memory institutionCourses = courses[institutionAddress];
        for (uint i = 0; i < institutionCourses.length; i++) {
            if (
                keccak256(abi.encodePacked(institutionCourses[i].code)) ==
                keccak256(abi.encodePacked(courseCode))
            ) {
                return (
                    institutions[institutionAddress],
                    institutionCourses[i]
                );
            }
        }
        revert("Course not found for student's associated institution!");
    }

    function getStudentTranscript(
        address _studentAddress
    ) public view returns (Grade[] memory, Discipline[] memory) {
        require(
            bytes(studentToCourse[_studentAddress]).length > 0,
            "Student not enrolled in any course or no course associated!"
        );
        Grade[] memory studentGrades = grades[_studentAddress];
        Discipline[] memory disciplineDetails = new Discipline[](
            studentGrades.length
        );
        bytes32 courseHash = keccak256(
            abi.encodePacked(studentToCourse[_studentAddress])
        );

        Discipline[] memory courseDisciplines = disciplinesByCourse[courseHash];
        require(
            courseDisciplines.length > 0,
            "No disciplines found for student's course!"
        );
        for (uint256 i = 0; i < studentGrades.length; i++) {
            bytes32 gradeDisciplineHash = keccak256(
                abi.encodePacked(studentGrades[i].disciplineCode)
            );
            bool foundDiscipline = false;
            for (uint256 j = 0; j < courseDisciplines.length; j++) {
                if (
                    keccak256(abi.encodePacked(courseDisciplines[j].code)) ==
                    gradeDisciplineHash
                ) {
                    disciplineDetails[i] = courseDisciplines[j];
                    foundDiscipline = true;
                    break;
                }
            }
            require(
                foundDiscipline,
                "Discipline for grade not found in course disciplines!"
            );
        }
        return (studentGrades, disciplineDetails);
    }

    function getStudentGrades(
        address _studentAddress
    ) public view returns (Grade[] memory) {
        return grades[_studentAddress];
    }

    function requestAccess(
        address _studentAddress,
        string calldata _encryptKey
    ) public studentExists(_studentAddress) {
        recipientEncryptKey[_studentAddress][msg.sender] = _encryptKey;
    }
}
