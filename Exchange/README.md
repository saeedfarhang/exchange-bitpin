# Exchange Dashboard - DevOps Interview

- [Exchange Dashboard - DevOps Interview](#exchange-dashboard---devops-interview)
  - [Build And Deploy](#build-and-deploy)
  - [CI/CD](#cicd)
  - [Migration](#migration)
  - [Port Forwarding](#port-forwarding)
  - [Data Protection](#data-protection)
    - [Backup](#backup)
    - [Restore](#restore)
      - [restore without dropping the DB](#restore-without-dropping-the-db)
  - [Trouble Shooting](#trouble-shooting)
  - [Rollback](#rollback)
  - [Workflows](#workflows)
  - [todos](#todos)

## Build And Deploy

there is a `docker` directory in root of the django project (where manage.py exists) that holds one Dockerfile for building this app. we can use it like:
`docker build . -f ./docker/Dockerfile -t exchange:local`
image name and tag can be anything you want.
we assume that this project is running on a minikube cluster with a `local storage` storage class configured. but you can adopt this to production grade clusters with few modifications.

on minikube we can load the built image into minikube environment with this command (on production you want a docker registry that your cluster have access to it and you push the images there):
`docker save exchange:local | docker exec -i minikube docker load`

in real cases you usually should change the image and pull policy in `k8s/django.yaml`file.

after this we can apply our manifests with this command in project root:
`kubectl apply -k k8s/`
this requires kubectl to support -k (kustomize) and works because of `k8s/kustomization.yaml` file.
this would deploy the app and apply the manifests we provided in `k8s/kustomization.yaml` file.

for production grade we want something more dynamic so we give the task of manifest generating to helm or tools like that.
wait ~3-4 mins. apps should come up and you can move further. check with
`kubectl -n django-app get pods`

you should see running state for all pods after a small wait time (so the images can get pulled and start jobs get finished and finally the app containers get into healthy state).

## CI/CD

GitHub Actions builds the image from `docker/Dockerfile`, scans it with Trivy, and pushes to GitHub Container Registry (`ghcr.io/<owner>/<repo>`).

- Workflow: [`.github/workflows/build-scan-push.yml`](../.github/workflows/build-scan-push.yml)
- Pull requests: build + Trivy only (no push)
- Push to `master`/`main` or a `v*` tag: build, scan, then push (`<sha>` and `latest` on the default branch)
- Trivy fails the job on unfixed `CRITICAL`/`HIGH` findings; SARIF is uploaded to GitHub Code Scanning

To use another registry (Docker Hub, Harbor, …) set repository variables `REGISTRY` and `IMAGE_NAME`, and replace the login step secrets (`DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` for Docker Hub).

After a successful push, point `k8s/django.yaml` at the published image and set `imagePullPolicy: IfNotPresent` (or `Always`) instead of `Never`.

## Migration

this app defines a job for migration that runs before the app container it self get initiate. check it in `k8s/django.yaml`
it runs automatically. just make sure you hold the correct env values and secrets in `k8s/config.yaml` and `k8s/secrets.yaml`.

\*do not share real secrets any where and only hold them where you need and keep them safe.\*

## Port Forwarding

for accessing the app through external (outside of the cluster) internet you can assign a free port on your host machine to this app port. do is like this:
`kubectl -n django-app port-forward svc/django 8000:8000`
and then the app should open up on <localhost|cluster_ip>:8000

## Data Protection

### Backup

backups runs automatically by a cronjob in `k8s/pg_backup.yaml` file. default schedule is "0 2 \* \* \*" (every days at 2:00 AM) but you can change it as you wish. it put backups in a pvc called `postgres-backups`. keep this pvc safe and make backups for that in case of disasters. for restore we are going to attach a temp container to the same pvc and use the backup data.

### Restore

exec into a temp postgres instance attached to the pvc contains backups (`postgres-backups`)

```
kubectl -n django-app run postgres-restore \
  --rm -it \
  --image=postgres:17 \
  --restart=Never \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "postgres-restore",
      "image": "postgres:17",
      "command": ["/bin/bash"],
      "stdin": true,
      "tty": true,
      "volumeMounts": [{
        "name": "backup",
        "mountPath": "/backup"
      }]
    }],
    "volumes": [{
      "name": "backup",
      "persistentVolumeClaim": {
        "claimName": "postgres-backups"
      }
    }]
  }
}'
```

from there run `ls -lh /backup`
inside the temp container run this and replace backup file name:

`export PGPASSWORD='your-password'`

#### restore without dropping the DB

```
pg_restore \
  --host=postgres \
  --port=5432 \
  --username=change_me \
  --dbname=exchange \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  /backup/<backup_name>.dump
```

## Trouble Shooting

find Trouble Shooting docs [here](./TROUBLESHOOTING.md)

## Rollback

for rollback this app related manifests, we should first delete the migrate job. do it with this command:
`kubectl -n django-app delete job django-migrate`

then we can apply safely and replace the changed resources with running same command we use for deploy:
`kubectl apply -k k8s/`

## Workflows

workflows can be find in parent repo (where git initiated). there you find a job for build, scan with Trivy and push image to an example registry. the image tag generated base on it's commit SHA.

## todos

- [ ] define health probe (readinessProbe, livenessProbe, startupProbe) for django app
- [ ] TLS (cluster issuer and cert manager config)
- [x] CI/CD (on github actions) with Trivy Scan
