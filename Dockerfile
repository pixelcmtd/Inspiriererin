FROM dart:stable AS build

WORKDIR /app
COPY pubspec.yaml .
RUN dart pub get
COPY bin ./bin
RUN dart compile exe bin/inspiriererin.dart -o bin/app

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/app /app/bin/

ENV INSP_DISCORD_TOKEN=
EXPOSE 8989

CMD ["/app/bin/app"]
