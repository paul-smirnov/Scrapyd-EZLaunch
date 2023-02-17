# Scrapyd-EZLaunch

Automated Scrapyd deployment in Docker

## Quick Start

### 1. Modifying Dependencies (optional)

Edit `requirements.txt` to suit your needs:

```bash
nano requirements.txt
```

### 2. Building and Publishing Docker Image

```bash
docker build -t geeeq2/scrapyd-env .
docker push geeeq2/scrapyd-env
```

### 3. Launch

```bash
sudo ./setup_scrapyd.sh
sudo ./setup_scrapyd.sh -e SCRAPYD_USERNAME=myuser -e SCRAPYD_PASSWORD=mypass
```

### 4. Login Credentials

After launch, credentials are saved in the `scrapyd_credentials.txt` file.
