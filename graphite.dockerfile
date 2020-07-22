FROM graphiteapp/graphite-statsd AS onlyoffice-graphite
LABEL maintainer Ascensio System SIA <support@onlyoffice.com>

RUN rm -rf /etc/service/statsd \
	&& sed 's|\#\?\(DASHBOARD_REQUIRE_AUTHENTICATION = \).*|\1True|g' \
		-i /opt/graphite/webapp/graphite/local_settings.py \
	&& sed '26s|\(retentions = \).*|\160s:90d|g' \
		-i /opt/graphite/conf/storage-schemas.conf
