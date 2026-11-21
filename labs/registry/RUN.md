# Tag, push and pull ShopKart (local registry + GHCR): tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

Starts from the `shopkart-api:1.1` image built in the Dockerfile lab.

## A. Your own registry

```console
$ docker network create shipping
6cf04ce87e3d415260308b1eeecda75b59b326c9933162fd5a8af5c112536e42
$ docker run -d --name registry --network shipping -p 5000:5000 -v registry-data:/var/lib/registry registry:2.8.3
Unable to find image 'registry:2.8.3' locally
2.8.3: Pulling from library/registry
6d464ea18732: Pulling fs layer
44cf07d57ee4: Pulling fs layer
bbbdd6c6894b: Pulling fs layer
8e82f80af0de: Pulling fs layer
3493bf46cdec: Pulling fs layer
3493bf46cdec: Download complete
44cf07d57ee4: Download complete
6d464ea18732: Download complete
bbbdd6c6894b: Download complete
8e82f80af0de: Download complete
44cf07d57ee4: Pull complete
32a76c78501f: Download complete
b537bf6d1146: Download complete
bbbdd6c6894b: Pull complete
8e82f80af0de: Pull complete
3493bf46cdec: Pull complete
6d464ea18732: Pull complete
Digest: sha256:a3d8aaa63ed8681a604f1dea0aa03f100d5895b6a58ace528858a7b332415373
Status: Downloaded newer image for registry:2.8.3
b465d39defdb2a33aff3210d439a6d88deb96c753d6a4ea2f40cf92ac7c212ac
$ docker tag shopkart-api:1.1 localhost:5000/shopkart-api:1.1
$ docker push localhost:5000/shopkart-api:1.1
The push refers to repository [localhost:5000/shopkart-api]
2dc99d2d0a39: Waiting
b30d4efa82df: Pushed
05e0eee5572e: Pushed
e313a7ad9e6d: Waiting
68bced9e0afa: Pushed
44136fa355b3: Pushed
d4c73e673483: Pushed
4253c1027130: Pushed
49197926995a: Pushed
37fb86c2a767: Pushed
2dc99d2d0a39: Pushed
e313a7ad9e6d: Pushed
1.1: digest: sha256:35a53779dedde1863304075fbb3f85ee65e650174622a3500917dfafbbd27ccb size: 856
$ curl -s localhost:5000/v2/_catalog
{"repositories":["shopkart-api"]}
$ curl -s localhost:5000/v2/shopkart-api/tags/list
{"name":"shopkart-api","tags":["1.1"]}
$ docker buildx imagetools inspect localhost:5000/shopkart-api:1.1 | head -n 4
Name:      localhost:5000/shopkart-api:1.1
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:35a53779dedde1863304075fbb3f85ee65e650174622a3500917dfafbbd27ccb
           
```

## B. The latest trap

```console
$ docker tag shopkart-api:1.1 localhost:5000/shopkart-api:latest
$ docker push localhost:5000/shopkart-api:latest
The push refers to repository [localhost:5000/shopkart-api]
68bced9e0afa: Layer already exists
b30d4efa82df: Already exists
37fb86c2a767: Layer already exists
05e0eee5572e: Layer already exists
e313a7ad9e6d: Layer already exists
44136fa355b3: Already exists
2dc99d2d0a39: Layer already exists
d4c73e673483: Layer already exists
4253c1027130: Layer already exists
49197926995a: Layer already exists
latest: digest: sha256:35a53779dedde1863304075fbb3f85ee65e650174622a3500917dfafbbd27ccb size: 856
$ curl -s localhost:5000/v2/shopkart-api/tags/list
{"name":"shopkart-api","tags":["latest","1.1"]}
```

## C. A clean machine

```console
$ docker run -d --privileged --name clean-machine --network shipping docker:29.10.0-dind --insecure-registry registry:5000
Unable to find image 'docker:29.10.0-dind' locally
29.10.0-dind: Pulling from library/docker
7d1715fa38ec: Pulling fs layer
881fc932939e: Pulling fs layer
e79a20f65ccf: Pulling fs layer
4f4fb700ef54: Pulling fs layer
80a1fa15fb80: Pulling fs layer
554970c1d0af: Pulling fs layer
a5da4a42f190: Pulling fs layer
dd5c7ebbff8d: Pulling fs layer
c0f0ba247ae4: Pulling fs layer
d5681b4d7626: Pulling fs layer
c01e603afa82: Pulling fs layer
2eec628ff29c: Pulling fs layer
671b73a663a8: Pulling fs layer
aa7a105296c3: Pulling fs layer
4adf556881df: Pulling fs layer
6183236cc14a: Pulling fs layer
881fc932939e: Already exists
6183236cc14a: Download complete
e79a20f65ccf: Download complete
4f4fb700ef54: Download complete
a5da4a42f190: Download complete
7d1715fa38ec: Download complete
80a1fa15fb80: Download complete
554970c1d0af: Download complete
c01e603afa82: Download complete
c0f0ba247ae4: Download complete
d5681b4d7626: Download complete
dd5c7ebbff8d: Download complete
671b73a663a8: Download complete
2eec628ff29c: Download complete
aa7a105296c3: Download complete
4adf556881df: Download complete
c8ae9b02a867: Download complete
e79a20f65ccf: Pull complete
4f4fb700ef54: Pull complete
80a1fa15fb80: Pull complete
554970c1d0af: Pull complete
a5da4a42f190: Pull complete
c0f0ba247ae4: Pull complete
d5681b4d7626: Pull complete
dd5c7ebbff8d: Pull complete
c01e603afa82: Pull complete
671b73a663a8: Pull complete
2eec628ff29c: Pull complete
aa7a105296c3: Pull complete
6183236cc14a: Pull complete
4adf556881df: Pull complete
7d1715fa38ec: Pull complete
Digest: sha256:4bbc7223f81db790097c6dea42fb93e05b8fead4f0431fbe6ccaba6e8473201c
Status: Downloaded newer image for docker:29.10.0-dind
b1b3f22c77cc185a2a49c448b9c31629d8be9d2bd29580bb866cfce6aa1562c7
$ docker exec clean-machine docker images
IMAGE   ID             DISK USAGE   CONTENT SIZE   EXTRA
$ DIGEST=$(docker buildx imagetools inspect localhost:5000/shopkart-api:1.1 --format '{{json .Manifest.Digest}}' | tr -d '"'); echo $DIGEST; docker exec clean-machine docker run -d --name api -p 8000:8000 "registry:5000/shopkart-api@$DIGEST"
sha256:35a53779dedde1863304075fbb3f85ee65e650174622a3500917dfafbbd27ccb
Unable to find image 'registry:5000/shopkart-api@sha256:35a53779dedde1863304075fbb3f85ee65e650174622a3500917dfafbbd27ccb' locally
registry:5000/shopkart-api@sha256:35a53779dedde1863304075fbb3f85ee65e650174622a3500917dfafbbd27ccb: Pulling from shopkart-api
49197926995a: Pulling fs layer
d4c73e673483: Pulling fs layer
05e0eee5572e: Pulling fs layer
68bced9e0afa: Pulling fs layer
37fb86c2a767: Pulling fs layer
2dc99d2d0a39: Pulling fs layer
4253c1027130: Pulling fs layer
e313a7ad9e6d: Pulling fs layer
d4c73e673483: Download complete
49197926995a: Download complete
68bced9e0afa: Download complete
2dc99d2d0a39: Download complete
05e0eee5572e: Download complete
4253c1027130: Download complete
e313a7ad9e6d: Download complete
b30d4efa82df: Download complete
44136fa355b3: Download complete
37fb86c2a767: Download complete
37fb86c2a767: Pull complete
68bced9e0afa: Pull complete
2dc99d2d0a39: Pull complete
05e0eee5572e: Pull complete
d4c73e673483: Pull complete
4253c1027130: Pull complete
e313a7ad9e6d: Pull complete
49197926995a: Pull complete
Digest: sha256:35a53779dedde1863304075fbb3f85ee65e650174622a3500917dfafbbd27ccb
Status: Downloaded newer image for registry:5000/shopkart-api@sha256:35a53779dedde1863304075fbb3f85ee65e650174622a3500917dfafbbd27ccb
aee22d8f89998c838e1a386de39d927b3fda7a50f509d13bdd62ba2b99f237cd
$ docker exec clean-machine wget -qO- localhost:8000/api/info; echo
{"app":"shopkart-api","version":"1.1","env":"local","db":"sqlite","banner":"","host":"aee22d8f8999"}
$ docker exec clean-machine docker images
IMAGE                                                                                                ID             DISK USAGE   CONTENT SIZE   EXTRA
registry:5000/shopkart-api@sha256:35a53779dedde1863304075fbb3f85ee65e650174622a3500917dfafbbd27ccb   35a53779dedd        240MB         58.4MB   U    
```

## D. GitHub Container Registry

Not recorded on the test VM: its GitHub token has no `write:packages` scope, so a push to ghcr.io is refused there. Record this step in the codespace (see README step D). The same image is pushed to GHCR by the CI/CD lab's pipeline, which was tested on GitHub Actions.

## Clean up

```console
$ docker rm -fv clean-machine registry
clean-machine
registry
$ docker volume rm registry-data
registry-data
$ docker network rm shipping
shipping
$ docker rmi localhost:5000/shopkart-api:1.1 localhost:5000/shopkart-api:latest
Untagged: localhost:5000/shopkart-api:1.1
Untagged: localhost:5000/shopkart-api:latest
```

