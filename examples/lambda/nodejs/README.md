# Rum Runner for NodeJS

A NodeJS project for AWS Lambda.

## Quickstart

Install Rum Runner:

```bash
gem install rumrunner
```

View Rum tasks:

```bash
rum --tasks
```

Run the default task to build the Lambda package, `lambda.zip`:

```bash
rum
```

Run through the `test` stage:

```bash
rum test
```

Run through the `plan` stage:

```bash
rum plan
```

Clean up Docker images and temporary files:

```bash
rum clean
```

Clobber created artifacts

```bash
rum clobber
```
