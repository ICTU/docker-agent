FROM mhart/alpine-node:4.2

RUN apk add --update bash openssh

ADD . /app

WORKDIR /app

RUN npm install

EXPOSE 80

CMD ["npm", "start"]
