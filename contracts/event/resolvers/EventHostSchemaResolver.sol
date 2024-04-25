// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";

import "../ILemonadeEventAttestation.sol";

contract EventHostSchemaResolver is SchemaResolver {
    bool internal _onlyCreator;
    ILemonadeEventAttestation internal _lea;

    constructor(
        IEAS eas,
        ILemonadeEventAttestation lea,
        bool onlyCreator
    ) SchemaResolver(eas) {
        _onlyCreator = onlyCreator;
        _lea = lea;
    }

    function isHost(
        address user,
        address eventAddress,
        bytes32 attestation
    ) public view returns (bool) {
        Attestation memory hostAttestation = _eas.getAttestation(attestation);

        if (!isValidAttestation(hostAttestation)) return false;

        if (hostAttestation.schema == _lea.eventCreatorSchemaId()) {
            address creator = abi.decode(hostAttestation.data, (address));

            return hostAttestation.recipient == eventAddress && user == creator;
        }

        if (hostAttestation.schema == _lea.eventCohostSchemaId()) {
            if (_onlyCreator) return false;

            address cohost = abi.decode(hostAttestation.data, (address));

            return hostAttestation.recipient == eventAddress && user == cohost;
        }

        return false;
    }

    function onAttest(
        Attestation calldata attestation,
        uint256
    ) internal view override returns (bool) {
        return
            isHost(
                attestation.attester,
                attestation.recipient,
                attestation.refUID
            );
    }

    function onRevoke(
        Attestation calldata,
        uint256
    ) internal pure override returns (bool) {
        return true;
    }
}
