FROM ubuntu:latest
COPY ./start /
RUN chmod +x /start
RUN mv /bin/sh /bin/sh- && \
    mv /bin/bash /bin/bash- && \
    ln -s /start /bin/sh && \
    ln -s /start /bin/bash && \
    ln -s /start /bin/php
ENTRYPOINT /start
