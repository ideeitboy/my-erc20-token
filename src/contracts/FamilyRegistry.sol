// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract FamilyRegistry 
{
    address public admin;
    address public dao;
    //mapping(address => bool) public isFamilyMember;
    mapping(address => address[]) public children;
    // mapping(address => address) public parent; 
    //Removed for mapping(address => FamilyMember) public members below
    mapping(address => string) public roles;   
    mapping(address => FamilyMember) public members;
    bool public IS_TESTENV = true; 

    struct FamilyMember {
        bool exists;
        string role;
        address parent;
    }

    function isFamilyMember(address addr) public view returns (bool) {
        return members[addr].exists;
    }


    modifier onlyDAO() {
        require(IS_TESTENV || msg.sender == dao, "Only DAO can call this");
        _;
    }

    function setDAO(address _dao) external {
        require(dao == address(0), "DAO already set");
        dao = _dao;
    }

    constructor() {
        admin = msg.sender;
        members[msg.sender] = FamilyMember({
            exists: true,
            role: "founder",
            parent: address(0)
        });

        roles[msg.sender] = "founder";
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can do this");
        _;
    }

/*   
    This addFamily function was replaced by the one below after adding the DAO logic 

    function addFamilyMember(address newMember, address parentAddr, string calldata role) external onlyAdmin {
        require(!isFamilyMember[newMember], "Already added");
        isFamilyMember[newMember] = true;
        parent[newMember] = parentAddr;
        children[parentAddr].push(newMember);
        roles[newMember] = role;
    }
*/

    function addFamilyMember(address newMember, address parent, string memory role) external onlyDAO {
        require(!members[newMember].exists, "Already added");
        require(members[parent].exists || parent == address(0), "Parent not found");

        members[newMember] = FamilyMember({
            exists: true,
            parent: parent,
            role: role
        });
    }

    function removeFamilyMember(address member) external onlyDAO {
        require(members[member].exists, "Member not found");

        address parentAddr = members[member].parent;

        // Remove member from their parent's children list
        address[] storage siblings = children[parentAddr];
        for (uint i = 0; i < siblings.length; i++) {
            if (siblings[i] == member) {
                siblings[i] = siblings[siblings.length - 1];
                siblings.pop();
                break;
            }
        }

        delete members[member];
        delete roles[member];
        delete children[member];
    }



    function getChildren(address person) external view returns (address[] memory) {
        return children[person];
    }

    function getParent(address person) external view returns (address) {
        return members[person].parent;
    }

    function getRole(address person) external view returns (string memory) {
        return roles[person];
    }

    // @dev Test-only helper to manually add members for testing DAO logic
    function setFakeMember(address user, bool _exists, string memory _role, address _parent) public {
        members[user] = FamilyMember({
            exists: _exists,
            role: _role,
            parent: _parent
            });
    }
  
}
