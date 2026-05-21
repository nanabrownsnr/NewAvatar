# Local submodule patches

This repository includes local fixes that are not upstreamed in two submodules:

- `src/service/frontend_service/frontend`
- `src/handlers/avatar/lam/LAM_Audio2Expression`

## Apply after clone

```bash
git submodule update --init --recursive
bash scripts/apply_local_submodule_patches.sh
```

## Rebuild WebUI bundle

After applying patches, rebuild frontend assets:

```bash
cd src/service/frontend_service/frontend
npm ci
npm run build
```

Then start the service/container as usual.
