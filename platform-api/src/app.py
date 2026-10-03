"""GET /platform/info: the infrastructure configuration this stage runs on.

Every value arrives as an environment variable that template.yaml resolved from
the SSM bridge (/platform/<stage>/*) at deploy time, so the function needs no SSM
permissions and makes no calls.
"""

import os

from aws_lambda_powertools import Logger, Tracer
from aws_lambda_powertools.event_handler import APIGatewayHttpResolver, CORSConfig
from aws_lambda_powertools.logging import correlation_paths
from aws_lambda_powertools.utilities.typing import LambdaContext

logger = Logger()
tracer = Tracer()
app = APIGatewayHttpResolver(cors=CORSConfig(allow_origin="*", max_age=300))


def _env(name: str) -> str:
    return os.environ.get(name, "")


def _list(name: str) -> list[str]:
    value = _env(name)
    return value.split(",") if value else []


def platform_info() -> dict:
    return {
        "stage": _env("STAGE"),
        "region": _env("AWS_REGION"),
        "infrastructure": {
            "vpc": {
                "vpc_id": _env("VPC_ID"),
                "private_subnet_ids": _list("PRIVATE_SUBNET_IDS"),
                "public_subnet_ids": _list("PUBLIC_SUBNET_IDS"),
            },
            "security_groups": {
                "lambda": _env("LAMBDA_SECURITY_GROUP_ID"),
                "vpc_link": _env("VPC_LINK_SECURITY_GROUP_ID"),
            },
            "vpc_link": {"id": _env("VPC_LINK_ID")},
            "dns": {
                "hosted_zone_id": _env("HOSTED_ZONE_ID"),
                "domain_name": _env("DOMAIN_NAME"),
                "certificate_arn": _env("CERTIFICATE_ARN"),
            },
            "appconfig": {
                "application_id": _env("APPCONFIG_APPLICATION_ID"),
                "environment_id": _env("APPCONFIG_ENVIRONMENT_ID"),
                "configuration_profile_id": _env("APPCONFIG_CONFIGURATION_PROFILE_ID"),
            },
        },
    }


@app.get("/platform/info")
@tracer.capture_method
def get_platform_info() -> dict:
    return platform_info()


@logger.inject_lambda_context(correlation_id_path=correlation_paths.API_GATEWAY_HTTP)
@tracer.capture_lambda_handler
def handler(event: dict, context: LambdaContext) -> dict:
    return app.resolve(event, context)
