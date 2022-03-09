import pytest


def pytest_sessionfinish(session, exitstatus):
    if exitstatus == pytest.ExitCode.NO_TESTS_COLLECTED:
        # we treat "no tests collected" as passing
        session.exitstatus = pytest.ExitCode.OK
