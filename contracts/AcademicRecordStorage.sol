// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/access/Ownable.sol"; 

contract AcademicRecordStorage is Ownable {
  struct Record {
    bytes32 recordId;
    address studentAddress;
    address institutionAddress;
    bytes encryptedData;
    bytes encryptedKeyInstitution;
    bytes encryptedKeyStudent;
    bytes signatureInstitution;
    uint256 timestamp;
  }
  mapping(bytes32 => Record) public records;
  mapping(bytes32 => mapping(address => bytes)) public visitorAccessKeys;
  
  event RecordRegistered(
    bytes32 indexed recordId,
    address indexed studentAddress,
    address indexed institutionAddress,
    uint256 timestamp
  );

  event AccessGranted(
    bytes32 indexed recordId,
    address indexed studentAddress,
    address indexed visitorAddress
  );

  event AccessRevoked(
    bytes32 indexed recordId,
    address indexed studentAddress,
    address indexed visitorAddress
  );

  mapping(address => bool) public isInstitution;

  constructor() Ownable(msg.sender) {} 

  modifier onlyInstitution() {
    require(isInstitution[msg.sender], "Caller is not an autorized institution");
    _;
  }

  function addInstitution(address _institution) public onlyOwner {
    require(_institution != address(0), "Institution address cannot be zero");
    isInstitution[_institution] = true;
  }
  function removeInstitution(address _institution) public onlyOwner {
    require(_institution != address(0), "Institution address cannot be zero");
    isInstitution[_institution] = false;
  }

  function registerBatchRecords(
    bytes32[] calldata _recordIds,
    address[] calldata _studentAddresses,
    bytes[] calldata _encryptedData,
    bytes[] calldata _encryptedKeyInstitution,
    bytes[] calldata _encryptedKeyStudent,
    bytes[] calldata _signaturesInstitution,
    string[] calldata _policies
  ) external onlyInstitution {
    require(
      _recordIds.length == _studentAddresses.length &&
      _recordIds.length == _encryptedData.length &&
      _recordIds.length == _encryptedKeyInstitution.length &&
      _recordIds.length == _encryptedKeyStudent.length &&
      _recordIds.length == _signaturesInstitution.length &&
      _recordIds.length == _policies.length,
      "Array lengths mismatch"
    );
    require(_recordIds.length > 0, "No records to register");
    for (uint i = 0; i < _recordIds.length; i++) {
      bytes32 currentRecordId = _recordIds[i];
      address currentStudentAddress = _studentAddresses[i];
      require(records[currentRecordId].studentAddress == address(0), "Record ID already exists");
      require(currentStudentAddress != address(0), "Student address cannot be zero");
      records[currentRecordId] = Record({
        recordId: currentRecordId,
        studentAddress: currentStudentAddress,
        institutionAddress: msg.sender,
        encryptedData: _encryptedData[i],
        encryptedKeyInstitution: _encryptedKeyInstitution[i],
        encryptedKeyStudent: _encryptedKeyStudent[i],
        signatureInstitution: _signaturesInstitution[i],
        timestamp: block.timestamp
        // policy: _policies[i] // Armazenando policy
      });
      emit RecordRegistered(
        currentRecordId,
        currentStudentAddress,
        msg.sender,
        block.timestamp
      );
    }
  }

  function grantVisitorAccess(bytes32 _recordId, address _visitorAddress, bytes calldata _encryptedKeyVisitor) public {
    require(records[_recordId].studentAddress == msg.sender, "Caller is not the student owner of this record");
    require(_visitorAddress != address(0), "Visitor address cannot be zero");
    require(_encryptedKeyVisitor.length > 0, "Encrypted key for visitor cannot be empty");
    visitorAccessKeys[_recordId][_visitorAddress] = _encryptedKeyVisitor;
    emit AccessGranted(_recordId, msg.sender, _visitorAddress);
  }

  function revokeVisitorAccess(bytes32 _recordId, address _visitorAddress) public {
    require(records[_recordId].studentAddress == msg.sender, "Caller is not the student owner of this record");
    require(_visitorAddress != address(0), "Visitor address cannot be zero");
    require(visitorAccessKeys[_recordId][_visitorAddress].length > 0, "Visitor does not have active access");
    delete visitorAccessKeys[_recordId][_visitorAddress]; 
    emit AccessRevoked(_recordId, msg.sender, _visitorAddress);
  }

  function getRecord(bytes32 _recordId) public view returns (Record memory) {
    require(records[_recordId].studentAddress != address(0), "Record not found");
    return records[_recordId];
  }
}
