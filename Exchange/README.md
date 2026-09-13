# Exchange Dashboard

## Port Forwarding

kubectl -n django-app port-forward svc/django 8000:8000

## Backup

exec into a temp postgres instance attached to the pvc contains backups

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

```
export PGPASSWORD='your-password'

pg_restore \
  --host=postgres \
  --port=5432 \
  --username=change_me \
  --dbname=exchange \
  --no-owner \
  --no-privileges \
  /backup/<backup_name>.dump
```

todos: - define health probe for django app -
