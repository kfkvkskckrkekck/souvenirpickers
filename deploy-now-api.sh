#!/bin/bash
cd dist && tar czf ../dist.tar.gz . && cd ..
curl -X POST \
  -H "Content-Type: application/x-tar" \
  -H "Authorization: Bearer nfp_DfAzR8idBnWkL9VPFiNAobD3mAA6Qe2d1ef0" \
  --data-binary @dist.tar.gz \
  "https://api.netlify.com/api/v1/sites/souvenirpickers/deploys"
