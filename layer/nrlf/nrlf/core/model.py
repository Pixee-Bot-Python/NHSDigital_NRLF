from typing import Union

from nhs_number import is_valid as is_valid_nhs_number
from pydantic import BaseModel, Extra, Field, StrictStr

import nrlf.consumer.fhir.r4.model as consumer_model
import nrlf.producer.fhir.r4.model as producer_model


class _NhsNumberMixin:
    @property
    def nhs_number(self) -> Union[str, None]:
        if self.subject_identifier is None:
            return None

        nhs_number = self.subject_identifier.__root__.split("|", 1)[1]

        if not is_valid_nhs_number(nhs_number):
            return None
            # raise ValueError(f"Not a valid NHS Number: {nhs_number}")

        return nhs_number


class ProducerRequestParams(producer_model.RequestParams, _NhsNumberMixin):
    pass


class ConsumerRequestParams(consumer_model.RequestParams, _NhsNumberMixin):
    class Config:
        extra = Extra.forbid

    pass


class CountRequestParams(consumer_model.CountRequestParams, _NhsNumberMixin):
    pass


class ReadDocumentReferencePathParams(BaseModel):
    id: StrictStr


class DeleteDocumentReferencePathParams(BaseModel):
    id: StrictStr


class UpdateDocumentReferencePathParams(BaseModel):
    id: StrictStr


class ClientRpDetails(BaseModel):
    developer_app_name: StrictStr = Field(alias="developer.app.name")
    developer_app_id: StrictStr = Field(alias="developer.app.id")


class ConnectionMetadata(BaseModel):
    pointer_types: list[str] = Field(alias="nrl.pointer-types", default_factory=list)
    ods_code: str = Field(alias="nrl.ods-code")
    ods_code_extension: str | None = Field(alias="nrl.ods-code-extension", default=None)
    nrl_permissions: list[str] = Field(alias="nrl.permissions", default_factory=list)
    enable_authorization_lookup: bool = Field(
        alias="nrl.enable-authorization-lookup", default=False
    )
    client_rp_details: ClientRpDetails

    @property
    def ods_code_parts(self):
        if self.ods_code_extension:
            return (self.ods_code, self.ods_code_extension)

        return (self.ods_code,)
