# Sample application image. Push this folder to any GitHub repo (or point
# github_repository at a repo that contains an equivalent Dockerfile).
#
# public.ecr.aws avoids Docker Hub anonymous pull-rate limits.
FROM public.ecr.aws/docker/library/python:3.12-alpine

WORKDIR /app
COPY index.html .

EXPOSE 80
CMD ["python3", "-m", "http.server", "80", "--bind", "0.0.0.0"]
