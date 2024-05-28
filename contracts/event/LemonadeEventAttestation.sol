// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/resolver/SchemaResolver.sol";
import "@ethereum-attestation-service/eas-contracts/contracts/resolver/examples/AttesterResolver.sol";

import "./ILemonadeEventAttestation.sol";
import "./resolvers/EventHostSchemaResolver.sol";
import "./resolvers/TicketTypeDetailSchemaResolver.sol";
import "./resolvers/TicketIssuingSchemaResolver.sol";

contract Event {}

string constant eventCreatorSchemaDefinition = "address creator, string creatorName, string creatorProfile, string eventLink, string externalId";
string constant eventCohostSchemaDefinition = "address cohost, string cohostName, string cohostProfile, string eventLink";
string constant eventDetailSchemaDefinition = "string title, string description, string date, string eventLink, string type, uint256 tickets, string creatorName, string creatorProfile";
string constant ticketTypeSchemaDefinition = "string eventName, string eventLink, string externalId";
string constant ticketTypeDetailSchemaDefinition = "bytes32 ticketTypeUID, string eventName, string eventLink, string title, string description, uint256 cost, string currency, string provider";
string constant ticketSchemaDefinition = "bytes32 ticketTypeUID, string guest, string eventName, string eventLink, string ticket, string assignedBy, string externalId";

contract LemonadeEventAttestation is
    OwnableUpgradeable,
    ILemonadeEventAttestation
{
    using ECDSA for bytes;
    using ECDSA for bytes32;

    bytes32 public eventCreatorSchemaId;
    bytes32 public eventDetailSchemaId;
    bytes32 public eventCohostSchemaId;
    bytes32 public ticketTypeSchemaId;
    bytes32 public ticketTypeDetailSchemaId;
    bytes32 public ticketSchemaId;

    IEAS internal _eas;
    ISchemaResolver internal lemonadeAttesterSchemaResolver;
    ISchemaResolver internal creatorSchemaResolver;
    EventHostSchemaResolver internal hostSchemaResolver;
    ISchemaResolver internal ticketSchemaResolver;
    ISchemaResolver internal ticketTypeDetailSchemaResolver;

    event EventCreated(
        address eventAddress,
        address creator,
        string externalId,
        bytes32 attestation
    );

    function initialize(address eas) public initializer {
        __Ownable_init();

        _eas = IEAS(eas);

        reinitResolversAndSchemas();
    }

    function registerEvent(
        string memory externalId,
        string memory creatorName,
        string memory creatorProfile,
        string memory eventLink
    ) external payable {
        address creator = _msgSender();

        Event event_ = new Event();

        address eventAddress = address(event_);

        AttestationRequestData memory data = AttestationRequestData(
            eventAddress,
            0,
            true,
            "",
            abi.encode(
                creator,
                creatorName,
                creatorProfile,
                eventLink,
                externalId
            ),
            msg.value
        );

        AttestationRequest memory request = AttestationRequest(
            eventCreatorSchemaId,
            data
        );

        bytes32 attestation = _eas.attest(request);

        emit EventCreated(eventAddress, creator, externalId, attestation);
    }

    function isValidTicket(
        bytes32 ticketUID,
        bytes calldata signature
    ) external view returns (bool) {
        bytes memory encoded = abi.encode(ticketUID);

        address signer = encoded.toEthSignedMessageHash().recover(signature);

        Attestation memory attestation = _eas.getAttestation(ticketUID);

        return
            isValidAttestation(attestation) &&
            attestation.schema == ticketSchemaId &&
            attestation.recipient == signer;
    }

    function reinitResolversAndSchemas() public onlyOwner {
        _reinitResolvers();

        reinitEventCreatorSchema();
        reinitEventCohostSchema();
        reinitEventDetailSchema();
        reinitTicketTypeSchema();
        reinitTicketTypeDetailSchema();
        reinitTicketSchema();
    }

    function reinitEventCreatorSchema() public onlyOwner {
        eventCreatorSchemaId = _eas.getSchemaRegistry().register(
            eventCreatorSchemaDefinition,
            lemonadeAttesterSchemaResolver,
            true
        );
    }

    function reinitEventCohostSchema() public onlyOwner {
        eventCohostSchemaId = _eas.getSchemaRegistry().register(
            eventCohostSchemaDefinition,
            creatorSchemaResolver,
            true
        );
    }

    function reinitEventDetailSchema() public onlyOwner {
        eventDetailSchemaId = _eas.getSchemaRegistry().register(
            eventDetailSchemaDefinition,
            hostSchemaResolver,
            true
        );
    }

    function reinitTicketTypeSchema() public onlyOwner {
        ticketTypeSchemaId = _eas.getSchemaRegistry().register(
            ticketTypeSchemaDefinition,
            hostSchemaResolver,
            true
        );
    }

    function reinitTicketTypeDetailSchema() public onlyOwner {
        ticketTypeDetailSchemaId = _eas.getSchemaRegistry().register(
            ticketTypeDetailSchemaDefinition,
            ticketTypeDetailSchemaResolver,
            true
        );
    }

    function reinitTicketSchema() public onlyOwner {
        ticketSchemaId = _eas.getSchemaRegistry().register(
            ticketSchemaDefinition,
            ticketSchemaResolver,
            true
        );
    }

    function _reinitResolvers() internal {
        lemonadeAttesterSchemaResolver = new AttesterResolver(
            _eas,
            address(this)
        );

        creatorSchemaResolver = new EventHostSchemaResolver(_eas, this, true);

        hostSchemaResolver = new EventHostSchemaResolver(_eas, this, false);

        ticketSchemaResolver = new TicketIssuingSchemaResolver(
            _eas,
            this,
            hostSchemaResolver
        );

        ticketTypeDetailSchemaResolver = new TicketTypeDetailSchemaResolver(
            _eas,
            this,
            hostSchemaResolver
        );
    }
}
