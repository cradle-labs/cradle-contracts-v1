// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import { AccessController } from "./AccessController.sol";

/**
AbstractContractAuthority
- ContractAuthority handles access control for subcontracts that're gonna be controlled by multiple super contracts
 */
abstract contract AbstractContractAuthority {

    uint64 public controlAllowList;
    AccessController public acl;

    modifier onlyAuthorized() {
        uint64[] memory allowList = _getAllowList(controlAllowList);

        bool hasAccess = false;
        for (uint i = 0; i < allowList.length; i++) {
            if (acl.hasAccess(allowList[i], msg.sender)) {
                hasAccess = true;
                break;
            }
        }

        require(hasAccess, "Unauthorized");
        _;
    }

    function _getAllowList(uint64 level) internal pure returns (uint64[] memory) {
        if (level == 0) {
            uint64[] memory list = new uint64[](1);
            list[0] = 0;
            return list;
        }else {
            // TODO: i'm temporarily enabling control access across the board because of uncertainities that I need to verify with actual testing, will reenable more granular control later
            uint64[] memory list = new uint64[](6);
            list[0] = 0;
            list[1] = 1;
            list[2] = 2;
            list[3] = 3;
            list[4] = 5;
            list[5] = 6;
            return list;
        }
    }

    constructor(address aclContract, uint64 _controlAllowList) {
        require(_controlAllowList <= 6, "Invalid control allow list level");
        controlAllowList = _controlAllowList;
        acl = AccessController(aclContract);
    }

    // Optional: Allow updating the control allow list
    function setControlAllowList(uint64 _newLevel) public virtual onlyAuthorized {
        require(_newLevel <= 6, "Invalid control allow list level");
        controlAllowList = _newLevel;
    }
}