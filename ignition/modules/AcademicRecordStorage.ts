import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const CONTRACT_NAME = "AcademicRecordStorage";
const MODULE_ID = "AcademicRecordStorageModule";

export default buildModule(MODULE_ID, (m) => {
  const academicRecordStorage = m.contract(CONTRACT_NAME);
  return { academicRecordStorage };
});
