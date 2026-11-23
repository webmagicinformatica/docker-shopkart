# Docker in CI/CD: pipeline and deploy (two parts): tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

## Part 1. The pipeline on GitHub Actions

Tested on GitHub Actions in the course repo: `done/pipeline.yml` copied to `.github/workflows/` on a test branch (trigger: push to that branch; everything else unchanged). The images went to `ghcr.io/webmagicinformatica/shopkart-api` and `shopkart-web`, tagged `sha-f77309d`. Output from `gh` on the test machine:

```console
$ gh run list --workflow pipeline.yml --limit 2
completed	success	test: newer action versions	.github/workflows/pipeline.yml	ci-lab-test	push	44946270449	1m32s	2026-11-21T20:26:14Z
completed	success	test: fix triggers	.github/workflows/pipeline.yml	ci-lab-test	push	44946069974	1m39s	2026-11-21T20:23:56Z
$ gh run view 44946270449

✓ ci-lab-test .github/workflows/pipeline.yml · 44946270449
Triggered via push about 2 minutes ago

JOBS
✓ test in 21s (ID 136974161352)
✓ build-scan-push in 1m6s (ID 136974266064)

$ gh run view 44946270449 --log | grep -E "passed|status|Scanning|pushing manifest" | cut -f2,3
Unit tests	9 passed in 0.48s
Smoke test	{"status":"ok","db":"ok","cart":"ok"}{"app":"shopkart-api","version":"sha-f77309d","env":"local","db":"sqlite","banner":"","host":"3045954d6ed1"}api
Scan with Trivy	Scanning shopkart-api:candidate
Scan with Trivy	Scanning shopkart-web:candidate
Push API	#16 pushing manifest for ghcr.io/webmagicinformatica/shopkart-api:sha-f77309d@sha256:c4294c25b341bcc09d27558aae9f115e77e775d414321f68b13ad0cee4718e0c 2.9s done
Push web	#10 pushing manifest for ghcr.io/webmagicinformatica/shopkart-web:sha-f77309d@sha256:cc959774be176858c16cc8a6d9a13fdd835e3eb6f6004eaaf385c632686f49d5 2.6s done
```

## Part 2. Deploy to a server

The test machine's GitHub token can't read private GHCR packages, so this run uses a local registry as a stand-in for ghcr.io: `IMAGE_PREFIX=registry:5000` instead of `ghcr.io/<you>`, and version tags `1.0.0`/`1.1.0` (what the pipeline makes for Git tags `v1.0.0`/`v1.1.0`) instead of `sha-` tags. Every deploy command is the same as in the README.

## Stand-in: a registry with two versions

```console
$ docker network create deploynet
e2377958d3469875eaabba1d04bdc982c605d99c630e97ae4f18df96997afdb5
$ docker run -d --name registry --network deploynet -p 5000:5000 registry:2.8.3
0ea938a504f9fe20ac562964a1bfcb639de31ad46c15e1a7b0cb9b71762ce775
$ for v in 1.0.0 1.1.0; do docker build -q --build-arg APP_VERSION=$v -t localhost:5000/shopkart-api:$v app/api && docker push -q localhost:5000/shopkart-api:$v; docker build -q -f app/web/Dockerfile -t localhost:5000/shopkart-web:$v app && docker push -q localhost:5000/shopkart-web:$v; done
sha256:3fd18418916f35a2199d704bb77d003eb0b593456d2472c3278cffab93eb4ff6
localhost:5000/shopkart-api:1.0.0
sha256:c3dbea1710df9bcbfd3fcdc866985c5504513eaff45974488daa7f83fc062385
localhost:5000/shopkart-web:1.0.0
sha256:cbfeb32e7c764190b9ce6a85d692f0530f79455de6bcfd3057fbdd59c3ccdd3d
localhost:5000/shopkart-api:1.1.0
sha256:34044e5261074180ea4d9cbba904c2f2039bc2aea93cf4fc47e54132b55a4729
localhost:5000/shopkart-web:1.1.0
```

## 4. A key and a server

```console
$ ssh-keygen -t ed25519 -N '' -f ~/.ssh/shopkart_deploy
Generating public/private ed25519 key pair.
Your identification has been saved in /home/vscode/.ssh/shopkart_deploy
Your public key has been saved in /home/vscode/.ssh/shopkart_deploy.pub
The key fingerprint is:
SHA256:+BptNY5GT+Op2E0dYBW4mwjnCcY7e2GY/z/B4gdoEDw vscode@2d904960f8be
The key's randomart image is:
+--[ED25519 256]--+
|     .     .o.   |
|      E   ..     |
|     . o  o.     |
|      *.....     |
|     ..XS+=+.    |
|      =+OB==o.   |
|      .**o*o..   |
|      .Bo+. o    |
|      o.o.oo..   |
+----[SHA256]-----+
$ docker build -t shopkart-server labs/ci-cd/server
[... 85 earlier lines of output cut ...]
#8 naming to docker.io/library/shopkart-server:latest done
#8 unpacking to docker.io/library/shopkart-server:latest 0.1s done
#8 DONE 0.8s
$ docker run -d --privileged --name shopkart-server --network deploynet -p 2222:22 -p 8081:80 \
  -e AUTHORIZED_KEY="$(cat ~/.ssh/shopkart_deploy.pub)" shopkart-server --insecure-registry registry:5000
de12ffdd849db4e135ddc27f4a02bd7d1d2834000b4c81776fae4754929d0695
$ cat >> ~/.ssh/config <<'CFG'
Host shopkart-server
  HostName localhost
  Port 2222
  User deploy
  IdentityFile ~/.ssh/shopkart_deploy
  StrictHostKeyChecking accept-new
CFG
$ ssh shopkart-server "docker version --format 'server engine {{.Server.Version}}'"
Warning: Permanently added '[localhost]:2222' (ED25519) to the list of known hosts.
server engine 29.10.0
```

## 5. A Docker context

```console
$ docker context create shopkart-server --docker host=ssh://shopkart-server
shopkart-server
Successfully created context "shopkart-server"
$ docker context ls
NAME              DESCRIPTION                               DOCKER ENDPOINT               ERROR
default *         Current DOCKER_HOST based configuration   unix:///var/run/docker.sock   
shopkart-server                                             ssh://shopkart-server         
$ docker --context shopkart-server ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

## 6. Deploy

```console
$ export IMAGE_PREFIX=registry:5000 TAG=1.0.0; docker --context shopkart-server compose -f labs/ci-cd/deploy/compose.yaml up -d --wait 2>&1 | grep -v -E 'Pulling fs layer|Download complete|Pull complete|Waiting|Already exists|Verifying|Extracting'
 web Pulling 
 api Pulling 
 seed Pulling 
 db Pulling 
 redis Pulling 
 893b1907c4dc Downloading [==>                                                ]  1.049MB/20.31MB
 9af591af458a Downloading [==================================================>]  2.272kB/2.272kB
 881fc932939e Downloading [========================================>          ]  3.146MB/3.854MB
 893b1907c4dc Downloading [===========================================>       ]  17.83MB/20.31MB
 4f56c5508527 Downloading [==================================================>]     405B/405B
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 9af591af458a Downloading [==================================================>]  2.272kB/2.272kB
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 1197128e240d Downloading [==================================================>]  1.884MB/1.884MB
 2631dab31190 Downloading [==================================================>]     629B/629B
 893b1907c4dc Downloading [==================================================>]  20.31MB/20.31MB
 4f56c5508527 Downloading [==================================================>]     405B/405B
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 9af591af458a Downloading [==================================================>]  2.272kB/2.272kB
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 1197128e240d Downloading [==================================================>]  1.884MB/1.884MB
 2631dab31190 Downloading [==================================================>]     629B/629B
 893b1907c4dc Downloading [==================================================>]  20.31MB/20.31MB
 4f56c5508527 Downloading [==================================================>]     405B/405B
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 9af591af458a Downloading [==================================================>]  2.272kB/2.272kB
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 1197128e240d Downloading [==================================================>]  1.884MB/1.884MB
 2631dab31190 Downloading [==================================================>]     629B/629B
 c188e096e949 Downloading [==================================================>]     965B/965B
 893b1907c4dc Downloading [==================================================>]  20.31MB/20.31MB
 e0c50520cf39 Downloading [=================================================> ]  3.146MB/3.206MB
 4f56c5508527 Downloading [==================================================>]     405B/405B
 cc0947b1a774 Downloading [==================================================>]  1.211kB/1.211kB
 61e5576dbd35 Downloading [==================================================>]  1.399kB/1.399kB
 4b0569278746 Downloading [==================================================>]     435B/435B
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 9af591af458a Downloading [==================================================>]  2.272kB/2.272kB
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 1197128e240d Downloading [==================================================>]  1.884MB/1.884MB
 2631dab31190 Downloading [==================================================>]     629B/629B
 c188e096e949 Downloading [==================================================>]     965B/965B
 893b1907c4dc Downloading [==================================================>]  20.31MB/20.31MB
 e0c50520cf39 Downloading [==================================================>]  3.206MB/3.206MB
 4f56c5508527 Downloading [==================================================>]     405B/405B
 cc0947b1a774 Downloading [==================================================>]  1.211kB/1.211kB
 61e5576dbd35 Downloading [==================================================>]  1.399kB/1.399kB
 4b0569278746 Downloading [==================================================>]     435B/435B
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 aa121b1b1cdb Downloading [==================================================>]    412kB/412kB
 1efc32d5f053 Downloading [===========================================>       ]  13.63MB/15.66MB
 2b3b8ff01576 Downloading [==================================================>]  15.21kB/15.21kB
 113b91713f05 Downloading [===========>                                       ]  3.146MB/13.78MB
 4b0569278746 Downloading [==================================================>]     435B/435B
 9af591af458a Downloading [==================================================>]  2.272kB/2.272kB
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 1197128e240d Downloading [==================================================>]  1.884MB/1.884MB
 2631dab31190 Downloading [==================================================>]     629B/629B
 c188e096e949 Downloading [==================================================>]     965B/965B
 893b1907c4dc Downloading [==================================================>]  20.31MB/20.31MB
 e0c50520cf39 Downloading [==================================================>]  3.206MB/3.206MB
 4f56c5508527 Downloading [==================================================>]     405B/405B
 cc0947b1a774 Downloading [==================================================>]  1.211kB/1.211kB
 61e5576dbd35 Downloading [==================================================>]  1.399kB/1.399kB
 113b91713f05 Downloading [==================================================>]  13.78MB/13.78MB
 cc36311dc778 Downloading [==================================================>]     248B/248B
 9b755c1d4ed7 Downloading [==================================================>]  3.475MB/3.475MB
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 aa121b1b1cdb Downloading [==================================================>]    412kB/412kB
 1efc32d5f053 Downloading [==================================================>]  15.66MB/15.66MB
 2b3b8ff01576 Downloading [==================================================>]  15.21kB/15.21kB
 893b1907c4dc Downloading [==================================================>]  20.31MB/20.31MB
 e0c50520cf39 Downloading [==================================================>]  3.206MB/3.206MB
 4f56c5508527 Downloading [==================================================>]     405B/405B
 cc0947b1a774 Downloading [==================================================>]  1.211kB/1.211kB
 61e5576dbd35 Downloading [==================================================>]  1.399kB/1.399kB
 4b0569278746 Downloading [==================================================>]     435B/435B
 9af591af458a Downloading [==================================================>]  2.272kB/2.272kB
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 1197128e240d Downloading [==================================================>]  1.884MB/1.884MB
 2631dab31190 Downloading [==================================================>]     629B/629B
 c188e096e949 Downloading [==================================================>]     965B/965B
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 aa121b1b1cdb Downloading [==================================================>]    412kB/412kB
 1efc32d5f053 Downloading [==================================================>]  15.66MB/15.66MB
 2b3b8ff01576 Downloading [==================================================>]  15.21kB/15.21kB
 113b91713f05 Downloading [==================================================>]  13.78MB/13.78MB
 cc36311dc778 Downloading [==================================================>]     248B/248B
 9b755c1d4ed7 Downloading [==================================================>]  3.475MB/3.475MB
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 1197128e240d Downloading [==================================================>]  1.884MB/1.884MB
 2631dab31190 Downloading [==================================================>]     629B/629B
 c188e096e949 Downloading [==================================================>]     965B/965B
 893b1907c4dc Downloading [==================================================>]  20.31MB/20.31MB
 e0c50520cf39 Downloading [==================================================>]  3.206MB/3.206MB
 4f56c5508527 Downloading [==================================================>]     405B/405B
 cc0947b1a774 Downloading [==================================================>]  1.211kB/1.211kB
 61e5576dbd35 Downloading [==================================================>]  1.399kB/1.399kB
 4b0569278746 Downloading [==================================================>]     435B/435B
 9af591af458a Downloading [==================================================>]  2.272kB/2.272kB
 881fc932939e Downloading [==================================================>]  3.854MB/3.854MB
 aa121b1b1cdb Downloading [==================================================>]    412kB/412kB
 693ad2f7a559 Downloading [==================================================>]      93B/93B
 1efc32d5f053 Downloading [==================================================>]  15.66MB/15.66MB
 f2118fa2d755 Downloading [==================================================>]  1.778kB/1.778kB
 2b3b8ff01576 Downloading [==================================================>]  15.21kB/15.21kB
 113b91713f05 Downloading [==================================================>]  13.78MB/13.78MB
 cc36311dc778 Downloading [==================================================>]     248B/248B
 9b755c1d4ed7 Downloading [==================================================>]  3.475MB/3.475MB
 44136fa355b3 Downloading [==================================================>]       2B/2B
 44136fa355b3 Downloading [==================================================>]       2B/2B
 c188e096e949 Downloading [==================================================>]     965B/965B
 e0c50520cf39 Downloading [==================================================>]  3.206MB/3.206MB
 cc0947b1a774 Downloading [==================================================>]  1.211kB/1.211kB
 61e5576dbd35 Downloading [==================================================>]  1.399kB/1.399kB
 4b0569278746 Downloading [==================================================>]     435B/435B
 f2118fa2d755 Downloading [==================================================>]  1.778kB/1.778kB
 2b3b8ff01576 Downloading [==================================================>]  15.21kB/15.21kB
 113b91713f05 Downloading [==================================================>]  13.78MB/13.78MB
 cc36311dc778 Downloading [==================================================>]     248B/248B
 9b755c1d4ed7 Downloading [==================================================>]  3.475MB/3.475MB
 44136fa355b3 Downloading [==================================================>]       2B/2B
 aa121b1b1cdb Downloading [==================================================>]    412kB/412kB
 693ad2f7a559 Downloading [==================================================>]      93B/93B
 1efc32d5f053 Downloading [==================================================>]  15.66MB/15.66MB
 44136fa355b3 Downloading [==================================================>]       2B/2B
 3315547c952c Downloading [==================================================>]  1.596kB/1.596kB
 693ad2f7a559 Downloading [==================================================>]      93B/93B
 1efc32d5f053 Downloading [==================================================>]  15.66MB/15.66MB
 f2118fa2d755 Downloading [==================================================>]  1.778kB/1.778kB
 113b91713f05 Downloading [==================================================>]  13.78MB/13.78MB
 cc36311dc778 Downloading [==================================================>]     248B/248B
 9b755c1d4ed7 Downloading [==================================================>]  3.475MB/3.475MB
 44136fa355b3 Downloading [==================================================>]       2B/2B
 3315547c952c Downloading [==================================================>]  1.596kB/1.596kB
 44136fa355b3 Downloading [==================================================>]       2B/2B
 3315547c952c Downloading [==================================================>]  1.596kB/1.596kB
 93bd71c0c19f Downloading [==================================================>]  2.101kB/2.101kB
 86c448f55957 Downloading [==================================================>]     949B/949B
 93bd71c0c19f Downloading [==================================================>]  2.101kB/2.101kB
 74c614fb2c68 Downloading [=============>                                     ]  1.049MB/3.853MB
 86c448f55957 Downloading [==================================================>]     949B/949B
 93bd71c0c19f Downloading [==================================================>]  2.101kB/2.101kB
 74c614fb2c68 Downloading [==================================================>]  3.853MB/3.853MB
 86c448f55957 Downloading [==================================================>]     949B/949B
 fe548a08e668 Downloading [======>                                            ]  4.194MB/33.83MB
 93bd71c0c19f Downloading [==================================================>]  2.101kB/2.101kB
 74c614fb2c68 Downloading [==================================================>]  3.853MB/3.853MB
 86c448f55957 Downloading [==================================================>]     949B/949B
 ded75ebb8133 Downloading [==================================================>]    201kB/201kB
 fe548a08e668 Downloading [==========>                                        ]   7.34MB/33.83MB
 4f4fb700ef54 Downloading [==================================================>]      32B/32B
 93bd71c0c19f Downloading [==================================================>]  2.101kB/2.101kB
 74c614fb2c68 Downloading [==================================================>]  3.853MB/3.853MB
 86c448f55957 Downloading [==================================================>]     949B/949B
 ded75ebb8133 Downloading [==================================================>]    201kB/201kB
 fe548a08e668 Downloading [===================================>               ]  24.12MB/33.83MB
 4f4fb700ef54 Downloading [==================================================>]      32B/32B
 93bd71c0c19f Downloading [==================================================>]  2.101kB/2.101kB
 74c614fb2c68 Downloading [==================================================>]  3.853MB/3.853MB
 86c448f55957 Downloading [==================================================>]     949B/949B
 ded75ebb8133 Downloading [==================================================>]    201kB/201kB
 fe548a08e668 Downloading [==================================================>]  33.83MB/33.83MB
 455b4655f37b Downloading [==================================================>]     100B/100B
 86c448f55957 Downloading [==================================================>]     949B/949B
 ded75ebb8133 Downloading [==================================================>]    201kB/201kB
 fe548a08e668 Downloading [==================================================>]  33.83MB/33.83MB
 455b4655f37b Downloading [==================================================>]     100B/100B
 4f4fb700ef54 Downloading [==================================================>]      32B/32B
 93bd71c0c19f Downloading [==================================================>]  2.101kB/2.101kB
 74c614fb2c68 Downloading [==================================================>]  3.853MB/3.853MB
 93bd71c0c19f Downloading [==================================================>]  2.101kB/2.101kB
 74c614fb2c68 Downloading [==================================================>]  3.853MB/3.853MB
 86c448f55957 Downloading [==================================================>]     949B/949B
 ded75ebb8133 Downloading [==================================================>]    201kB/201kB
 fe548a08e668 Downloading [==================================================>]  33.83MB/33.83MB
 455b4655f37b Downloading [==================================================>]     100B/100B
 4f4fb700ef54 Downloading [==================================================>]      32B/32B
 347a7fa9ed72 Downloading [==================================================>]  6.105kB/6.105kB
 93bd71c0c19f Downloading [==================================================>]  2.101kB/2.101kB
 74c614fb2c68 Downloading [==================================================>]  3.853MB/3.853MB
 86c448f55957 Downloading [==================================================>]     949B/949B
 ded75ebb8133 Downloading [==================================================>]    201kB/201kB
 fe548a08e668 Downloading [==================================================>]  33.83MB/33.83MB
 455b4655f37b Downloading [==================================================>]     100B/100B
 4f4fb700ef54 Downloading [==================================================>]      32B/32B
 5bc1f3ef349d Downloading [==================================================>]     992B/992B
 347a7fa9ed72 Downloading [==================================================>]  6.105kB/6.105kB
 b88a5d98edb6 Downloading [==================================================>]     186B/186B
 74c614fb2c68 Downloading [==================================================>]  3.853MB/3.853MB
 ded75ebb8133 Downloading [==================================================>]    201kB/201kB
 fe548a08e668 Downloading [==================================================>]  33.83MB/33.83MB
 455b4655f37b Downloading [==================================================>]     100B/100B
 4f4fb700ef54 Downloading [==================================================>]      32B/32B
 347a7fa9ed72 Downloading [==================================================>]  6.105kB/6.105kB
 b88a5d98edb6 Downloading [==================================================>]     186B/186B
 5bc1f3ef349d Downloading [==================================================>]     992B/992B
 fe548a08e668 Downloading [==================================================>]  33.83MB/33.83MB
 455b4655f37b Downloading [==================================================>]     100B/100B
 347a7fa9ed72 Downloading [==================================================>]  6.105kB/6.105kB
 b88a5d98edb6 Downloading [==================================================>]     186B/186B
 5bc1f3ef349d Downloading [==================================================>]     992B/992B
 329a9259bb19 Downloading [==================================================>]  901.1kB/901.1kB
 3bfefdb8e856 Downloading [==================================================>]     116B/116B
 3bfefdb8e856 Downloading [==================================================>]     116B/116B
 c795bf66a383 Downloading [====>                                              ]  9.437MB/112.6MB
 329a9259bb19 Downloading [==================================================>]  901.1kB/901.1kB
 c795bf66a383 Downloading [===========>                                       ]  26.21MB/112.6MB
 3834788888c5 Downloading [==================================================>]     170B/170B
 c795bf66a383 Downloading [==================>                                ]  40.89MB/112.6MB
 517559d123bd Downloading [==================================================>]  9.998kB/9.998kB
 c795bf66a383 Downloading [========================>                          ]  55.57MB/112.6MB
 3834788888c5 Downloading [==================================================>]     170B/170B
 c795bf66a383 Downloading [================================>                  ]   73.4MB/112.6MB
 3834788888c5 Downloading [==================================================>]     170B/170B
 435551e8de65 Downloading [==================================================>]  466.5kB/466.5kB
 c795bf66a383 Downloading [================================>                  ]   73.4MB/112.6MB
 3834788888c5 Downloading [==================================================>]     170B/170B
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 435551e8de65 Downloading [==================================================>]  466.5kB/466.5kB
 c795bf66a383 Downloading [========================================>          ]  90.18MB/112.6MB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 435551e8de65 Downloading [==================================================>]  466.5kB/466.5kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 c795bf66a383 Downloading [========================================>          ]  90.18MB/112.6MB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 435551e8de65 Downloading [==================================================>]  466.5kB/466.5kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 c795bf66a383 Downloading [==========================================>        ]  96.47MB/112.6MB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 435551e8de65 Downloading [==================================================>]  466.5kB/466.5kB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 c795bf66a383 Downloading [===============================================>   ]  105.9MB/112.6MB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 435551e8de65 Downloading [==================================================>]  466.5kB/466.5kB
 c795bf66a383 Downloading [==================================================>]  112.6MB/112.6MB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 435551e8de65 Downloading [==================================================>]  466.5kB/466.5kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 c795bf66a383 Downloading [==================================================>]  112.6MB/112.6MB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 435551e8de65 Downloading [==================================================>]  466.5kB/466.5kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 c795bf66a383 Downloading [==================================================>]  112.6MB/112.6MB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 435551e8de65 Downloading [==================================================>]  466.5kB/466.5kB
 c795bf66a383 Downloading [==================================================>]  112.6MB/112.6MB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 435551e8de65 Downloading [==================================================>]  466.5kB/466.5kB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 c795bf66a383 Downloading [==================================================>]  112.6MB/112.6MB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 c795bf66a383 Downloading [==================================================>]  112.6MB/112.6MB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 c795bf66a383 Downloading [==================================================>]  112.6MB/112.6MB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 c795bf66a383 Downloading [==================================================>]  112.6MB/112.6MB
 ceb080f17589 Downloading [==================================================>]  30.07kB/30.07kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 c795bf66a383 Downloading [==================================================>]  112.6MB/112.6MB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 d6bd5d959dd4 Downloading [==================================================>]    598kB/598kB
 c795bf66a383 Downloading [==================================================>]  112.6MB/112.6MB
 fc266ea8b801 Downloading [==================================================>]  39.83kB/39.83kB
 c795bf66a383 Downloading [==================================================>]  112.6MB/112.6MB
 web Pulled 
 seed Pulled 
 api Pulled 
 redis Pulled 
 db Pulled 
 Network shopkart_default  Creating
 Network shopkart_default  Created
 Volume shopkart_db-data  Creating
 Volume shopkart_db-data  Created
 Container shopkart-db-1  Creating
 Container shopkart-redis-1  Creating
 Container shopkart-redis-1  Created
 Container shopkart-db-1  Created
 Container shopkart-seed-1  Creating
 Container shopkart-seed-1  Created
 Container shopkart-api-1  Creating
 Container shopkart-api-1  Created
 Container shopkart-web-1  Creating
 Container shopkart-web-1  Created
 Container shopkart-redis-1  Starting
 Container shopkart-db-1  Starting
 Container shopkart-db-1  Started
 Container shopkart-redis-1  Started
 Container shopkart-db-1  Healthy
 Container shopkart-seed-1  Starting
 Container shopkart-seed-1  Started
 Container shopkart-seed-1  Exited
 Container shopkart-api-1  Starting
 Container shopkart-api-1  Started
 Container shopkart-api-1  Healthy
 Container shopkart-web-1  Starting
 Container shopkart-web-1  Started
 Container shopkart-api-1  Healthy
 Container shopkart-redis-1  Healthy
 Container shopkart-db-1  Healthy
 Container shopkart-seed-1  Exited
 Container shopkart-web-1  Healthy
$ export IMAGE_PREFIX=registry:5000 TAG=1.0.0; docker --context shopkart-server compose -f labs/ci-cd/deploy/compose.yaml ps -a --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}'
SERVICE   IMAGE                              STATUS
api       registry:5000/shopkart-api:1.0.0   Up 17 seconds (healthy)
db        postgres:17.12-alpine              Up 25 seconds (healthy)
redis     redis:8.8.4-alpine                 Up 25 seconds
seed      registry:5000/shopkart-api:1.0.0   Exited (0) 17 seconds ago
web       registry:5000/shopkart-web:1.0.0   Up 11 seconds (healthy)
$ curl -s localhost:8081/api/info; echo
{"app":"shopkart-api","version":"1.0.0","env":"production","db":"postgres","banner":"","host":"91808919f3ef"}
$ curl -s -X POST localhost:8081/api/cart/deploy-test/items -H 'Content-Type: application/json' -d '{"product_id": 4, "qty": 1}'; echo
{"cart_id":"deploy-test","items":[{"product_id":4,"name":"Wireless Earbuds","qty":1,"price_inr":1799,"line_total_inr":1799}],"total_inr":1799}
```

## 7. Roll out a new version

```console
$ export IMAGE_PREFIX=registry:5000 TAG=1.1.0; docker --context shopkart-server compose -f labs/ci-cd/deploy/compose.yaml up -d --wait 2>&1 | grep -v -E 'Pulling fs layer|Download complete|Pull complete|Waiting|Already exists|Verifying|Extracting'
 api Pulling 
 seed Pulling 
 web Pulling 
 74033e53184c Downloading [==============================>                    ]  2.097MB/3.475MB
 74033e53184c Downloading [==================================================>]  3.475MB/3.475MB
 dd3d813396e6 Downloading [==================================================>]      92B/92B
 74033e53184c Downloading [==================================================>]  3.475MB/3.475MB
 0234a226d6aa Downloading [==================================================>]  1.779kB/1.779kB
 web Pulled 
 api Pulled 
 seed Pulled 
 Container shopkart-redis-1  Running
 Container shopkart-db-1  Running
 Container shopkart-seed-1  Recreate
 Container shopkart-seed-1  Recreated
 Container shopkart-api-1  Recreate
 Container shopkart-api-1  Recreated
 Container shopkart-web-1  Recreate
 Container shopkart-web-1  Recreated
 Container shopkart-db-1  Healthy
 Container shopkart-seed-1  Starting
 Container shopkart-seed-1  Started
 Container shopkart-seed-1  Exited
 Container shopkart-api-1  Starting
 Container shopkart-api-1  Started
 Container shopkart-api-1  Healthy
 Container shopkart-web-1  Starting
 Container shopkart-web-1  Started
 Container shopkart-db-1  Healthy
 Container shopkart-api-1  Healthy
 Container shopkart-redis-1  Healthy
 Container shopkart-seed-1  Exited
 Container shopkart-web-1  Healthy
$ curl -s localhost:8081/api/info; echo
{"app":"shopkart-api","version":"1.1.0","env":"production","db":"postgres","banner":"","host":"73718dd6f658"}
$ curl -s localhost:8081/api/cart/deploy-test; echo
{"cart_id":"deploy-test","items":[{"product_id":4,"name":"Wireless Earbuds","qty":1,"price_inr":1799,"line_total_inr":1799}],"total_inr":1799}
```

## 8. Roll back

```console
$ export IMAGE_PREFIX=registry:5000 TAG=1.0.0; docker --context shopkart-server compose -f labs/ci-cd/deploy/compose.yaml up -d --wait 2>&1 | tail -n 3
 Container shopkart-redis-1  Healthy
 Container shopkart-api-1  Healthy
 Container shopkart-web-1  Healthy
$ curl -s localhost:8081/api/info; echo
{"app":"shopkart-api","version":"1.0.0","env":"production","db":"postgres","banner":"","host":"96f608d571c9"}
```

## 9. Clean up

```console
$ export IMAGE_PREFIX=registry:5000 TAG=1.0.0; docker --context shopkart-server compose -f labs/ci-cd/deploy/compose.yaml down -v 2>&1 | tail -n 2
 Volume shopkart_db-data  Removed
 Network shopkart_default  Removed
$ docker context rm shopkart-server
shopkart-server
$ docker rm -fv shopkart-server registry
shopkart-server
registry
$ docker network rm deploynet
deploynet
$ sed -i '/^Host shopkart-server$/,/StrictHostKeyChecking/d' ~/.ssh/config; rm ~/.ssh/shopkart_deploy ~/.ssh/shopkart_deploy.pub
```

