import json
import urllib.parse
from logging import Logger
from typing import Any

from aws_lambda_powertools.utilities.parser.models import APIGatewayProxyEventModel
from lambda_pipeline.types import FrozenDict, LambdaContext, PipelineData
from lambda_utils.header_config import ClientRpDetailsHeader
from lambda_utils.logging import log_action
from nrlf.core.errors import AuthenticationError
from nrlf.core.query import hard_delete_query
from nrlf.core.repository import Repository
from nrlf.core.validators import generate_producer_id


@log_action(narrative="Parsing ClientRpDetails header")
def parse_client_rp_details(
    data: PipelineData,
    context: LambdaContext,
    event: APIGatewayProxyEventModel,
    dependencies: FrozenDict[str, Any],
    logger: Logger,
) -> PipelineData:
    client_rp_details = ClientRpDetailsHeader(event)
    return PipelineData(**data, client_rp_details=client_rp_details)


@log_action(narrative="Parsing producer permissions")
def parse_producer_permissions(
    data: PipelineData,
    context: LambdaContext,
    event: APIGatewayProxyEventModel,
    dependencies: FrozenDict[str, Any],
    logger: Logger,
) -> PipelineData:
    client_rp_details = json.loads(event.headers["NHSD-Client-RP-Details"])
    return PipelineData(
        pointer_types=client_rp_details["nrl.pointer-types"],
        **data,
    )


def _invalid_producer_for_delete(
    client_rp_details: ClientRpDetailsHeader, delete_item_id: str
):
    producer_id = generate_producer_id(id=delete_item_id, producer_id=None)
    if not client_rp_details.custodian == producer_id:
        return True
    return False


def _producer_not_exists(client_rp_details: ClientRpDetailsHeader):
    return not client_rp_details.custodian


@log_action(narrative="Validating producer permissions")
def validate_producer_permissions(
    data: PipelineData,
    context: LambdaContext,
    event: APIGatewayProxyEventModel,
    dependencies: FrozenDict[str, Any],
    logger: Logger,
) -> PipelineData:
    client_rp_details: ClientRpDetailsHeader = data["client_rp_details"]
    decoded_id = urllib.parse.unquote(event.pathParameters["id"])
    if _producer_not_exists(client_rp_details=client_rp_details):
        raise AuthenticationError("Custodian does not exist in the system")

    if _invalid_producer_for_delete(
        client_rp_details=client_rp_details, delete_item_id=decoded_id
    ):
        raise AuthenticationError(
            "Required permission to delete a document pointer are missing"
        )

    return PipelineData(decoded_id=decoded_id, **data)


@log_action(narrative="Deleting document reference")
def delete_document_reference(
    data: PipelineData,
    context: LambdaContext,
    event: APIGatewayProxyEventModel,
    dependencies: FrozenDict[str, Any],
    logger: Logger,
) -> PipelineData:
    repository: Repository = dependencies["repository"]
    query = hard_delete_query(
        id=data["decoded_id"], type=data["client_rp_details"].pointer_types
    )
    repository.hard_delete(**query)
    return PipelineData(message="Resource removed")


steps = [
    parse_client_rp_details,
    validate_producer_permissions,
    delete_document_reference,
]
