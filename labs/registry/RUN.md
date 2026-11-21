# Tag, push and pull ShopKart (local registry + GHCR): tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

Starts from the `shopkart-api:1.1` image built in the Dockerfile lab.

## A. Your own registry

```console
$ docker network create shipping
94730d77546f24835272d63ddc67e50b1fc1abe4cb034f6e8680161c32bcaa8e
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
bbbdd6c6894b: Download complete
6d464ea18732: Download complete
44cf07d57ee4: Pull complete
bbbdd6c6894b: Pull complete
8e82f80af0de: Download complete
32a76c78501f: Download complete
b537bf6d1146: Download complete
3493bf46cdec: Pull complete
8e82f80af0de: Pull complete
6d464ea18732: Pull complete
Digest: sha256:a3d8aaa63ed8681a604f1dea0aa03f100d5895b6a58ace528858a7b332415373
Status: Downloaded newer image for registry:2.8.3
1da6644685229bee31c47803392075af1a0dffd788ae5345761ec1bc1dc4cc6e
$ docker tag shopkart-api:1.1 localhost:5000/shopkart-api:1.1
$ docker push localhost:5000/shopkart-api:1.1
The push refers to repository [localhost:5000/shopkart-api]
44136fa355b3: Pushed
03cced7934a8: Pushed
68bced9e0afa: Pushed
2d35fdb785f0: Pushed
8db45d7aea48: Waiting
05e0eee5572e: Pushed
9cf9f29a4d7f: Pushed
a29848ec0088: Pushed
37fb86c2a767: Pushed
2dc99d2d0a39: Pushed
8db45d7aea48: Pushed
1.1: digest: sha256:33417eb02681a1d5c909df4b494712652e798b82fb71d54b325f4f09105b4d59 size: 856
$ curl -s localhost:5000/v2/_catalog
{"repositories":["shopkart-api"]}
$ curl -s localhost:5000/v2/shopkart-api/tags/list
{"name":"shopkart-api","tags":["1.1"]}
$ docker buildx imagetools inspect localhost:5000/shopkart-api:1.1 | head -n 4
Name:      localhost:5000/shopkart-api:1.1
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:33417eb02681a1d5c909df4b494712652e798b82fb71d54b325f4f09105b4d59
           
```

## B. The latest trap

```console
$ docker tag shopkart-api:1.1 localhost:5000/shopkart-api:latest
$ docker push localhost:5000/shopkart-api:latest
The push refers to repository [localhost:5000/shopkart-api]
03cced7934a8: Layer already exists
8db45d7aea48: Layer already exists
68bced9e0afa: Layer already exists
44136fa355b3: Already exists
2d35fdb785f0: Already exists
05e0eee5572e: Layer already exists
9cf9f29a4d7f: Layer already exists
a29848ec0088: Layer already exists
37fb86c2a767: Layer already exists
2dc99d2d0a39: Layer already exists
latest: digest: sha256:33417eb02681a1d5c909df4b494712652e798b82fb71d54b325f4f09105b4d59 size: 856
$ curl -s localhost:5000/v2/shopkart-api/tags/list
{"name":"shopkart-api","tags":["latest","1.1"]}
```

## C. A clean machine

```console
$ docker run -d --privileged --name clean-machine --network shipping docker:29.10.0-dind --insecure-registry registry:5000
Unable to find image 'docker:29.10.0-dind' locally
29.10.0-dind: Pulling from library/docker
671b73a663a8: Pulling fs layer
e79a20f65ccf: Pulling fs layer
d5681b4d7626: Pulling fs layer
2eec628ff29c: Pulling fs layer
7d1715fa38ec: Pulling fs layer
c01e603afa82: Pulling fs layer
aa7a105296c3: Pulling fs layer
c0f0ba247ae4: Pulling fs layer
881fc932939e: Pulling fs layer
80a1fa15fb80: Pulling fs layer
554970c1d0af: Pulling fs layer
a5da4a42f190: Pulling fs layer
dd5c7ebbff8d: Pulling fs layer
4adf556881df: Pulling fs layer
6183236cc14a: Pulling fs layer
4f4fb700ef54: Pulling fs layer
881fc932939e: Already exists
4f4fb700ef54: Download complete
671b73a663a8: Download complete
d5681b4d7626: Download complete
e79a20f65ccf: Download complete
2eec628ff29c: Download complete
7d1715fa38ec: Download complete
c01e603afa82: Download complete
c0f0ba247ae4: Download complete
aa7a105296c3: Download complete
80a1fa15fb80: Download complete
554970c1d0af: Download complete
6183236cc14a: Download complete
dd5c7ebbff8d: Download complete
a5da4a42f190: Download complete
c8ae9b02a867: Download complete
4adf556881df: Download complete
e79a20f65ccf: Pull complete
4f4fb700ef54: Pull complete
80a1fa15fb80: Pull complete
554970c1d0af: Pull complete
a5da4a42f190: Pull complete
c0f0ba247ae4: Pull complete
dd5c7ebbff8d: Pull complete
d5681b4d7626: Pull complete
c01e603afa82: Pull complete
671b73a663a8: Pull complete
2eec628ff29c: Pull complete
aa7a105296c3: Pull complete
4adf556881df: Pull complete
7d1715fa38ec: Pull complete
6183236cc14a: Pull complete
Digest: sha256:4bbc7223f81db790097c6dea42fb93e05b8fead4f0431fbe6ccaba6e8473201c
Status: Downloaded newer image for docker:29.10.0-dind
e2cd4581e864ae7985a609d4e99aa3719c5be87e5da9c4e360b6bab0f9a43075
$ docker exec clean-machine docker images
IMAGE   ID             DISK USAGE   CONTENT SIZE   EXTRA
$ DIGEST=$(docker buildx imagetools inspect localhost:5000/shopkart-api:1.1 --format '{{json .Manifest.Digest}}' | tr -d '"'); echo $DIGEST; docker exec clean-machine docker run -d --name api -p 8000:8000 "registry:5000/shopkart-api@$DIGEST"
sha256:33417eb02681a1d5c909df4b494712652e798b82fb71d54b325f4f09105b4d59
Unable to find image 'registry:5000/shopkart-api@sha256:33417eb02681a1d5c909df4b494712652e798b82fb71d54b325f4f09105b4d59' locally
registry:5000/shopkart-api@sha256:33417eb02681a1d5c909df4b494712652e798b82fb71d54b325f4f09105b4d59: Pulling from shopkart-api
a29848ec0088: Pulling fs layer
37fb86c2a767: Pulling fs layer
68bced9e0afa: Pulling fs layer
2dc99d2d0a39: Pulling fs layer
05e0eee5572e: Pulling fs layer
03cced7934a8: Pulling fs layer
9cf9f29a4d7f: Pulling fs layer
8db45d7aea48: Pulling fs layer
a29848ec0088: Download complete
2dc99d2d0a39: Download complete
05e0eee5572e: Download complete
03cced7934a8: Download complete
68bced9e0afa: Download complete
8db45d7aea48: Download complete
2d35fdb785f0: Download complete
44136fa355b3: Download complete
37fb86c2a767: Download complete
9cf9f29a4d7f: Download complete
37fb86c2a767: Pull complete
68bced9e0afa: Pull complete
2dc99d2d0a39: Pull complete
05e0eee5572e: Pull complete
03cced7934a8: Pull complete
9cf9f29a4d7f: Pull complete
8db45d7aea48: Pull complete
a29848ec0088: Pull complete
Digest: sha256:33417eb02681a1d5c909df4b494712652e798b82fb71d54b325f4f09105b4d59
Status: Downloaded newer image for registry:5000/shopkart-api@sha256:33417eb02681a1d5c909df4b494712652e798b82fb71d54b325f4f09105b4d59
a9cd1d6553b688e9cbd40998fa351b0e3bfddb85502bdf257eae6567bae7fc70
$ docker exec clean-machine wget -qO- localhost:8000/api/info; echo
{"app":"shopkart-api","version":"1.1","env":"local","db":"sqlite","banner":"","host":"a9cd1d6553b6"}
$ docker exec clean-machine docker images
IMAGE                                                                                                ID             DISK USAGE   CONTENT SIZE   EXTRA
registry:5000/shopkart-api@sha256:33417eb02681a1d5c909df4b494712652e798b82fb71d54b325f4f09105b4d59   33417eb02681        240MB         58.4MB   U    
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

