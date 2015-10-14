FROM mhart/alpine-node

RUN apk add --update bash openssh

ADD . /app

WORKDIR /app

RUN npm install

CMD ["npm", "start"]
