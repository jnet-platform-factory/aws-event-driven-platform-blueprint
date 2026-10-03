# base-layer

The Python libraries most of **TENANT**'s functions share, as one Lambda layer
(`__PREFIX__-base-python313`, Python 3.13, arm64). The libraries are pinned in
[layer/requirements.txt](layer/requirements.txt); `sam build` installs them for the Lambda
runtime and architecture, and the stack publishes a new layer version whenever they
change.

The current version's ARN is written to SSM at `/layers/<stage>/base`. A function
uses it with a parameter:

```yaml
Parameters:
  BaseLayerArn:
    Type: AWS::SSM::Parameter::Value<String>
    Default: /layers/dev/base
Resources:
  Function:
    Type: AWS::Serverless::Function
    Properties:
      Layers: [!Ref BaseLayerArn]
      Architectures: [arm64]
```

Old versions are retained, so a function keeps the version it was deployed with until
it is redeployed.

```bash
make check                                    # sam validate, parameter files; no AWS
make build                                    # build in the Lambda image, import every library (Docker)
make changeset STAGE=dev                      # executes nothing
make execute   STAGE=dev CHANGE_SET=<name>    # after reading it
```

To change a library: edit `layer/requirements.txt`, run `make build`, and open a pull
request; its change set shows the new layer version.
