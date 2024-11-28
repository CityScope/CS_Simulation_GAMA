FROM gamaplatform/gama

WORKDIR /working_dir

VOLUME /working_dir

EXPOSE 8000

CMD ["gama", "-socket", "8000"]
