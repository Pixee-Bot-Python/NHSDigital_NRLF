from tests.smoke.setup import build_document_reference
from tests.utilities.api_clients import ProducerTestClient


def test_producer_crud(
    producer_client: ProducerTestClient, test_nhs_numbers: list[str]
):
    """
    Smoke test scenario for producer CRUD behaviour
    """
    test_docref = build_document_reference(nhs_number=test_nhs_numbers[0])

    try:
        # Create
        create_response = producer_client.create(test_docref.dict())
        assert create_response.ok
        created_id = create_response.headers["Location"].split("/")[-1]

        # Read
        read_response = producer_client.read(created_id)
        assert read_response.ok
        assert read_response.json()["id"] == created_id

        # Update
        updated_docref = {
            **test_docref.dict(),
            "id": created_id,
        }
        updated_docref["content"][0]["attachment"][
            "url"
        ] = "https://testing.record-locator.national.nhs.uk/_smoke_test_pointer_content_updated"
        update_response = producer_client.update(updated_docref, created_id)
        assert update_response.ok
    finally:
        # Delete
        delete_response = producer_client.delete(created_id)
        assert delete_response.ok

        # Read again, expect a 404
        read_response = producer_client.read(created_id)
        assert read_response.status_code == 404
