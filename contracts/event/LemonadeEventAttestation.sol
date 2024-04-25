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

string constant eventCreatorSchemaDefinition = "address creator, string externalId";
string constant eventCohostSchemaDefinition = "address cohost";
string constant eventDetailSchemaDefinition = "string title, string description, uint256 start, uint256 end, string location";
string constant ticketTypeSchemaDefinition = "string externalId";
string constant ticketTypeDetailSchemaDefinition = "bytes32 ticketTypeUID, string title, string description, address currency, uint256 cost";
string constant ticketSchemaDefinition = "bytes32 ticketTypeUID, string externalId";

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

    event EventCreated(
        address eventAddress,
        address creator,
        string externalId,
        bytes32 attestation
    );

    function initialize(address eas) public initializer {
        __Ownable_init();

        _eas = IEAS(eas);

        _initSchemas();
    }

    function registerEvent(string memory externalId) external payable {
        address creator = _msgSender();

        Event event_ = new Event();

        address eventAddress = address(event_);

        AttestationRequestData memory data = AttestationRequestData(
            eventAddress,
            0,
            true,
            "",
            abi.encode(creator, externalId),
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

    function _initSchemas() internal onlyInitializing {
        ISchemaResolver lemonadeAttesterSchemaResolver = new AttesterResolver(
            _eas,
            address(this)
        );

        ISchemaResolver creatorSchemaResolver = new EventHostSchemaResolver(
            _eas,
            this,
            true
        );

        EventHostSchemaResolver hostSchemaResolver = new EventHostSchemaResolver(
            _eas,
            this,
            false
        );

        ISchemaResolver ticketSchemaResolver = new TicketIssuingSchemaResolver(
            _eas,
            this,
            hostSchemaResolver
        );

        ISchemaResolver ticketTypeDetailSchemaResolver = new TicketTypeDetailSchemaResolver(
            _eas,
            this,
            hostSchemaResolver
        );

        _initEventCreatorSchema(lemonadeAttesterSchemaResolver);
        _initEventCohostSchema(creatorSchemaResolver);
        _initEventDetailSchema(hostSchemaResolver);
        _initTicketTypeSchema(hostSchemaResolver);
        _initTicketTypeDetailSchema(ticketTypeDetailSchemaResolver);
        _initTicketSchema(ticketSchemaResolver);
    }

    function _initEventCreatorSchema(
        ISchemaResolver resolver
    ) internal onlyInitializing {
        eventCreatorSchemaId = _eas.getSchemaRegistry().register(
            eventCreatorSchemaDefinition,
            resolver,
            true
        );
    }

    function _initEventCohostSchema(
        ISchemaResolver resolver
    ) internal onlyInitializing {
        eventCohostSchemaId = _eas.getSchemaRegistry().register(
            eventCohostSchemaDefinition,
            resolver,
            true
        );
    }

    function _initEventDetailSchema(
        ISchemaResolver resolver
    ) internal onlyInitializing {
        eventDetailSchemaId = _eas.getSchemaRegistry().register(
            eventDetailSchemaDefinition,
            resolver,
            true
        );
    }

    function _initTicketTypeSchema(
        ISchemaResolver resolver
    ) internal onlyInitializing {
        ticketTypeSchemaId = _eas.getSchemaRegistry().register(
            ticketTypeSchemaDefinition,
            resolver,
            true
        );
    }

    function _initTicketTypeDetailSchema(
        ISchemaResolver resolver
    ) internal onlyInitializing {
        ticketTypeDetailSchemaId = _eas.getSchemaRegistry().register(
            ticketTypeDetailSchemaDefinition,
            resolver,
            true
        );
    }

    function _initTicketSchema(
        ISchemaResolver resolver
    ) internal onlyInitializing {
        ticketSchemaId = _eas.getSchemaRegistry().register(
            ticketSchemaDefinition,
            resolver,
            true
        );
    }
}
