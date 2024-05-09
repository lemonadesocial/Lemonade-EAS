// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";

import "../ILemonadeEventAttestation.sol";
import "./EventHostSchemaResolver.sol";

contract TicketIssuingSchemaResolver is SchemaResolver {
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
        address attester = attestation.attester;

        if (attester == attestation.recipient) {
            //-- it's user trying to attest his owned ticket
            Attestation memory ticketAttestation = _eas.getAttestation(
                attestation.refUID
            );

            return
                isValidAttestation(ticketAttestation) &&
                ticketAttestation.schema == _lea.ticketSchemaId() &&
                ticketAttestation.recipient == attester;
        } else {
            //-- it's host attesting ticket for user
            bytes32 ticketTypeUID = abi.decode(attestation.data, (bytes32));

            Attestation memory ticketTypeAttestation = _eas.getAttestation(
                ticketTypeUID
            );

            return
                isValidAttestation(ticketTypeAttestation) &&
                _hostResolver.isHost(
                    attester,
                    ticketTypeAttestation.recipient,
                    attestation.refUID
                );
        }
    }

    function onRevoke(
        Attestation calldata,
        uint256
    ) internal pure override returns (bool) {
        return true;
    }
}
