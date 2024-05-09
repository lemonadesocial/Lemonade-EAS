// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";

import "../ILemonadeEventAttestation.sol";
import "./EventHostSchemaResolver.sol";

contract TicketTypeDetailSchemaResolver is SchemaResolver {
    bool internal _onlyCreator;
    ILemonadeEventAttestation internal _lea;
    EventHostSchemaResolver internal _hostResolver;

    constructor(
        IEAS eas,
        ILemonadeEventAttestation lea,
        EventHostSchemaResolver hostResolver
    ) SchemaResolver(eas) {
        _lea = lea;
        _hostResolver = hostResolver;
    }

    function onAttest(
        Attestation calldata attestation,
        uint256
    ) internal view override returns (bool) {
        bytes32 ticketTypeUID = abi.decode(attestation.data, (bytes32));

        Attestation memory ticketTypeAttestation = _eas.getAttestation(
            ticketTypeUID
        );

        address eventAddress = ticketTypeAttestation.recipient;

        return
            attestation.recipient == eventAddress &&
            isValidAttestation(ticketTypeAttestation) &&
            ticketTypeAttestation.schema == _lea.ticketTypeSchemaId() &&
            _hostResolver.isHost(
                attestation.attester,
                eventAddress,
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
