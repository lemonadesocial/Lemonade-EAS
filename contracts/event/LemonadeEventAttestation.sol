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
string constant ticketTypeSchemaDefinition = "string event, string eventLink, string externalId";
string constant ticketTypeDetailSchemaDefinition = "string event, string eventLink, string title, string description, uint256 cost, string currency, string provider, bytes32 ticketTypeUID";
string constant ticketSchemaDefinition = "string guest, string event, string eventLink, string ticket, string assignedBy, bytes32 ticketTypeUID, string externalId";

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
        reinitSchemas();
    }

    function reinitSchemas() public onlyOwner {
        _initEventCreatorSchema(lemonadeAttesterSchemaResolver);
        _initEventCohostSchema(creatorSchemaResolver);
        _initEventDetailSchema(hostSchemaResolver);
        _initTicketTypeSchema(hostSchemaResolver);
        _initTicketTypeDetailSchema(ticketTypeDetailSchemaResolver);
        _initTicketSchema(ticketSchemaResolver);
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

    function _initEventCreatorSchema(ISchemaResolver resolver) internal {
        eventCreatorSchemaId = _eas.getSchemaRegistry().register(
            eventCreatorSchemaDefinition,
            resolver,
            true
        );
    }

    function _initEventCohostSchema(ISchemaResolver resolver) internal {
        eventCohostSchemaId = _eas.getSchemaRegistry().register(
            eventCohostSchemaDefinition,
            resolver,
            true
        );
    }

    function _initEventDetailSchema(ISchemaResolver resolver) internal {
        eventDetailSchemaId = _eas.getSchemaRegistry().register(
            eventDetailSchemaDefinition,
            resolver,
            true
        );
    }

    function _initTicketTypeSchema(ISchemaResolver resolver) internal {
        ticketTypeSchemaId = _eas.getSchemaRegistry().register(
            ticketTypeSchemaDefinition,
            resolver,
            true
        );
    }

    function _initTicketTypeDetailSchema(ISchemaResolver resolver) internal {
        ticketTypeDetailSchemaId = _eas.getSchemaRegistry().register(
            ticketTypeDetailSchemaDefinition,
            resolver,
            true
        );
    }

    function _initTicketSchema(ISchemaResolver resolver) internal {
        ticketSchemaId = _eas.getSchemaRegistry().register(
            ticketSchemaDefinition,
            resolver,
            true
        );
    }
}
