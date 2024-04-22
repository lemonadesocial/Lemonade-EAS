// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";

import "../ILemonadeEventAttestation.sol";
import "./EventHostSchemaResolver.sol";

contract TicketTypeDetailSchemaResolver is SchemaResolver {
    bool internal onlyCreator;
    ILemonadeEventAttestation internal lea;
    EventHostSchemaResolver internal hostResolver;

    constructor(
        IEAS _eas,
        ILemonadeEventAttestation _lea,
        EventHostSchemaResolver _hostResolver
    ) SchemaResolver(_eas) {
        lea = _lea;
        hostResolver = _hostResolver;
    }

    function onAttest(
        Attestation calldata _attestation,
        uint256
    ) internal view override returns (bool) {
        Attestation memory ticketTypeAttestation = _eas.getAttestation(
            _attestation.refUID
        );

        address eventAddress = ticketTypeAttestation.recipient;

        return
            _attestation.recipient == eventAddress &&
            isValidAttestation(ticketTypeAttestation) &&
            ticketTypeAttestation.schema == lea.ticketTypeSchemaId() &&
            hostResolver.isHost(
                _attestation.attester,
                eventAddress,
                ticketTypeAttestation.refUID
            );
    }

    function onRevoke(
        Attestation calldata,
        uint256
    ) internal pure override returns (bool) {
        return true;
    }
}
