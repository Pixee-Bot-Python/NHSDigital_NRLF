from typing import Any, Generator

import pytest

from tests.smoke.setup import build_document_reference, upsert_test_pointer
from tests.utilities.api_clients import ProducerTestClient


@pytest.fixture
def test_data(
    test_nhs_numbers: list[str], producer_client: ProducerTestClient
) -> Generator[str, Any, None]:
    test_pointers = [
        upsert_test_pointer(
            f"SMOKETEST-producer_count_search_read_pointer_{n}",
            docref=build_document_reference(nhs_number=test_nhs_numbers[0]),
            producer_client=producer_client,
        )
        for n in range(0, 5)
    ]

    test_data = {
        "patient_nhs_number": test_nhs_numbers[0],
        "pointers": test_pointers,
    }

    yield test_data

    for test_pointer in test_pointers:
        producer_client.delete(test_pointer.id)


def test_producer_search_read(producer_client: ProducerTestClient, test_data: dict):
    """
    Smoke test scenario for a producer search and read behaviour
    """
    patient_id = test_data["patient_nhs_number"]
    test_pointers = test_data["pointers"]

    # Search
    search_response = producer_client.search(patient_id)
    assert search_response.ok
    assert search_response.json()["total"] == len(test_pointers)
    # TODO-NOW - Check each id maybe?

    # TODO-NOW - Add a test for post search

    # Read
    read_response = producer_client.read(test_pointers[0].id)
    assert read_response.ok
    assert read_response.json()["id"] == test_pointers[0].id
    assert read_response.json()["subject"]["identifier"]["value"] == patient_id
    assert read_response.json()["status"] == "current"
