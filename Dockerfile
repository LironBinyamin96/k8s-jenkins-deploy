# Dockerfile
FROM nginx:latest

# Overwrite the default index.html with a test page
COPY ./index.html /usr/share/nginx/html/index.html

RUN echo /usr/share/nginx/html/index.html

# Expose the default HTTP port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
