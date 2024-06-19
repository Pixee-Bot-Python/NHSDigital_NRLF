import sys
from abc import ABC
from typing import Generic, Iterator, List, Optional, Type, TypeVar

from botocore.exceptions import ClientError
from pydantic import ValidationError

from nrlf.core.boto import get_dynamodb_resource, get_dynamodb_table
from nrlf.core.codes import SpineErrorConcept
from nrlf.core.dynamodb.model import DocumentPointer, DynamoDBModel
from nrlf.core.errors import OperationOutcomeError
from nrlf.core.logger import LogReference, logger

RepositoryModel = TypeVar("RepositoryModel", bound=DynamoDBModel)


def _get_cat_for_type(pointer_type: str) -> str:
    return "734163000"


class Repository(ABC, Generic[RepositoryModel]):
    ITEM_TYPE: Type[RepositoryModel]

    def __init__(self, environment_prefix: str = ""):
        self.dynamodb = get_dynamodb_resource()
        self.table_name = environment_prefix + self.ITEM_TYPE.kebab()
        self.table = get_dynamodb_table(self.table_name)
        logger.log(
            LogReference.REPOSITORY001,
            table_name=self.table_name,
            item_type=self.ITEM_TYPE.__name__,
        )


class DocumentPointerRepository(Repository[DocumentPointer]):
    ITEM_TYPE = DocumentPointer

    def create(self, item: DocumentPointer) -> DocumentPointer:
        """
        Create a DocumentPointer resource
        """
        logger.log(
            LogReference.REPOSITORY002,
            indexes=item.indexes,
            type=item.type,
            source=item.source,
            version=item.version,
        )

        try:
            result = self.table.put_item(
                Item=item.dict(),
                ConditionExpression="attribute_not_exists(pk) AND attribute_not_exists(sk)",
                ReturnConsumedCapacity="INDEXES",
            )
            logger.log(LogReference.REPOSITORY003, result=result)

        except ClientError as exc:
            if (
                exc.response.get("Error", {}).get("Code")
                == "ConditionalCheckFailedException"
            ):
                logger.log(LogReference.REPOSITORY004)
                raise OperationOutcomeError(
                    status_code="409",
                    severity="error",
                    code="conflict",
                    details=SpineErrorConcept.from_code("DUPLICATE_REJECTED"),
                ) from None

            logger.log(
                LogReference.REPOSITORY005,
                exc_info=sys.exc_info(),
                stacklevel=5,
                error=str(exc),
            )
            raise exc

        return item

    def get_by_id(self, id: str) -> Optional[DocumentPointer]:
        """
        Get a DocumentPointer resource by ID
        """

        ods_code, doc_id = id.split("-")
        doc_key = f"O#{ods_code}#D#{doc_id}"

        try:
            result = self.table.query(
                IndexName="dockey_gsi",
                KeyConditionExpression="doc_key = :doc_key",
                ExpressionAttributeValues={":doc_key": doc_key},
                ReturnConsumedCapacity="INDEXES",
            )
        except ClientError as exc:
            logger.log(
                LogReference.REPOSITORY007,
                exc_info=sys.exc_info(),
                stacklevel=5,
                error=str(exc),
            )
            raise exc

        if result["Count"] == 0:
            logger.log(LogReference.REPOSITORY012)
            return None

        if result["Count"] > 1:
            logger.log(LogReference.REPOSITORY008)
            raise OperationOutcomeError(
                status_code="500",
                severity="error",
                code="exception",
                details=SpineErrorConcept.from_code("INTERNAL_SERVER_ERROR"),
            )

        item = result["Items"][0]
        try:
            parsed_item = self.ITEM_TYPE.parse_obj({"_from_dynamo": True, **item})
            logger.log(LogReference.REPOSITORY011)
            logger.log(LogReference.REPOSITORY011a, result=parsed_item.dict())
            return parsed_item
        except ValidationError as exc:
            logger.log(
                LogReference.REPOSITORY010,
                exc_info=sys.exc_info(),
                stacklevel=5,
                error=str(exc),
            )
            raise OperationOutcomeError(
                status_code="500",
                severity="error",
                code="exception",
                details=SpineErrorConcept.from_code("INTERNAL_SERVER_ERROR"),
            ) from exc

    def count_by_nhs_number(
        self,
        nhs_number: str,
        pointer_types: Optional[List[str]] = None,
    ) -> int:
        """
        Count all DocumentPointer records by NHS number
        """
        logger.log(
            LogReference.REPOSITORY013,
            nhs_number=nhs_number,
            pointer_types=pointer_types,
        )

        key_conditions = ["pk = :pk"]
        filter_expressions = []
        expression_names = {}
        expression_values = {":pk": f"P#{nhs_number}"}

        if len(pointer_types) == 1:
            # Optimisation for single pointer type
            category = _get_cat_for_type(pointer_types[0])
            sort_key = f"C#{category}#T#{pointer_types[0]}"
            key_conditions.append("begins_with(sk, :sk)")
            expression_values[":sk"] = sort_key

        # Handle multiple categories and pointer types with filter expressions
        if len(pointer_types) > 1:
            # TODO - Is it quicker to do multi searches?
            expression_names["#pointer_type"] = "type"
            types_filters = [
                f"#pointer_type = :type_{i}" for i in range(len(pointer_types))
            ]
            types_filter_values = {
                f":type_{i}": pointer_types[i] for i in range(len(pointer_types))
            }
            filter_expressions.append(f"({' OR '.join(types_filters)})")
            expression_values.update(types_filter_values)

        query = {
            "KeyConditionExpression": " AND ".join(key_conditions),
            "FilterExpression": " AND ".join(filter_expressions),
            "ExpressionAttributeNames": expression_names or None,
            "ExpressionAttributeValues": expression_values,
            "Select": "COUNT",
            "ReturnConsumedCapacity": "INDEXES",
        }

        logger.log(LogReference.REPOSITORY017, query=query)

        try:
            result = self.table.query(**query)
        except ClientError as exc:
            logger.log(
                LogReference.REPOSITORY019,
                exc_info=sys.exc_info(),
                stacklevel=5,
                error=str(exc),
            )
            raise OperationOutcomeError(
                status_code="500",
                severity="error",
                code="exception",
                details=SpineErrorConcept.from_code("INTERNAL_SERVER_ERROR"),
            ) from exc

        logger.log(LogReference.REPOSITORY018, count=result["Count"])
        logger.log(LogReference.REPOSITORY018a, result=result)

        return result["Count"]

    def search(
        self,
        nhs_number: str,
        custodian: Optional[str] = None,
        pointer_types: Optional[List[str]] = [],
    ) -> Iterator[DocumentPointer]:
        """"""
        logger.log(
            LogReference.REPOSITORY020,
            nhs_number=nhs_number,
            custodian=custodian,
            pointer_types=pointer_types,
        )

        key_conditions = ["pk = :pk"]
        filter_expressions = []
        expression_names = {}
        expression_values = {":pk": f"P#{nhs_number}"}

        if len(pointer_types) == 1:
            # Optimisation for single pointer type
            category = _get_cat_for_type(pointer_types[0])
            sort_key = f"C#{category}#T#{pointer_types[0]}"
            key_conditions.append("begins_with(sk, :sk)")
            expression_values[":sk"] = sort_key

        # Handle multiple categories and pointer types with filter expressions
        if len(pointer_types) > 1:
            # TODO - Is it quicker to do multi searches?
            expression_names["#pointer_type"] = "type"
            types_filters = [
                f"#pointer_type = :type_{i}" for i in range(len(pointer_types))
            ]
            types_filter_values = {
                f":type_{i}": pointer_types[i] for i in range(len(pointer_types))
            }
            filter_expressions.append(f"({' OR '.join(types_filters)})")
            expression_values.update(types_filter_values)

        if custodian:
            logger.log(
                LogReference.REPOSITORY016,
                expression="custodian = :custodian",
                values=["custodian"],
            )
            filter_expressions.append("custodian = :custodian")
            expression_values[":custodian"] = custodian

        query = {
            "KeyConditionExpression": " AND ".join(key_conditions),
            "FilterExpression": " AND ".join(filter_expressions),
            "ExpressionAttributeNames": expression_names or None,
            "ExpressionAttributeValues": expression_values,
            "ReturnConsumedCapacity": "INDEXES",
        }

        yield from self._query(**query)

    def save(self, item: DocumentPointer) -> DocumentPointer:
        """
        Save a DocumentPointer resource
        """
        if not item._from_dynamo:
            logger.log(LogReference.REPOSITORY023)
            return self.create(item)

        logger.log(LogReference.REPOSITORY024)
        return self.update(item)

    def supersede(
        self,
        item: DocumentPointer,
        pointers_to_delete: List[str],
        can_ignore_delete_fail: bool = False,
    ) -> DocumentPointer:
        """ """
        saved_item = self.create(item)

        for pointer in pointers_to_delete:
            self.delete(pointer, ignore_fail=can_ignore_delete_fail)

        return saved_item

    def delete(self, item: DocumentPointer, ignore_fail: bool = False) -> None:
        """
        Delete a DocumentPointer
        """
        logger.log(LogReference.REPOSITORY025, partition_key=item.pk, sort_key=item.sk)

        try:
            result = self.table.delete_item(
                Key={"pk": item.pk, "sk": item.sk},
                ConditionExpression="attribute_exists(pk) AND attribute_exists(sk)",
                ReturnConsumedCapacity="INDEXES",
            )
            logger.log(LogReference.REPOSITORY027, result=result)

        except ClientError as exc:
            logger.log(
                LogReference.REPOSITORY026,
                exc_info=sys.exc_info(),
                stacklevel=5,
                error=str(exc),
            )

            if ignore_fail:
                return

            raise OperationOutcomeError(
                status_code="500",
                severity="error",
                code="exception",
                details=SpineErrorConcept.from_code("INTERNAL_SERVER_ERROR"),
            ) from exc

    def _query(self, **kwargs) -> Iterator[DocumentPointer]:
        """
        Wrapper around DynamoDB query method to handle pagination
        Returns an iterator of DocumentPointer objects
        """
        # Remove empty fields from the search query
        query = {key: value for key, value in kwargs.items() if value}

        logger.log(LogReference.REPOSITORY021, query=query, table=self.table_name)

        try:
            paginator = self.dynamodb.meta.client.get_paginator("query")
            response_iterator = paginator.paginate(TableName=self.table_name, **query)

            for page in response_iterator:
                logger.log(
                    LogReference.REPOSITORY028,
                    stats={
                        "count": page["Count"],
                        "scanned_count": page["ScannedCount"],
                        "last_evaluated_key": page.get("LastEvaluatedKey"),
                    },
                )
                logger.log(LogReference.REPOSITORY028a, result=page)

                for item in page["Items"]:
                    try:
                        yield self.ITEM_TYPE.parse_obj({"_from_dynamo": True, **item})

                    except ValidationError as exc:
                        logger.log(
                            LogReference.REPOSITORY010,
                            exc_info=sys.exc_info(),
                            stacklevel=5,
                            error=str(exc),
                        )
                        raise OperationOutcomeError(
                            status_code="500",
                            severity="error",
                            code="exception",
                            details=SpineErrorConcept.from_code(
                                "INTERNAL_SERVER_ERROR"
                            ),
                        ) from exc

        except ClientError as exc:
            logger.log(
                LogReference.REPOSITORY022,
                exc_info=sys.exc_info(),
                stacklevel=5,
                error=str(exc),
            )
            raise exc

    def update(self, item: DocumentPointer) -> DocumentPointer:
        """
        Update a DocumentPointer resource
        """
        try:
            result = self.table.put_item(
                Item=item.dict(),
                ConditionExpression="attribute_exists(pk) AND attribute_exists(sk)",
                ReturnConsumedCapacity="INDEXES",
            )
            logger.log(LogReference.REPOSITORY029a, result=result)
        except ClientError as exc:
            logger.log(
                LogReference.REPOSITORY023,
                exc_info=sys.exc_info(),
                stacklevel=5,
                error=str(exc),
            )
            raise OperationOutcomeError(
                status_code="500",
                severity="error",
                code="exception",
                details=SpineErrorConcept.from_code("INTERNAL_SERVER_ERROR"),
            ) from exc

        return item
