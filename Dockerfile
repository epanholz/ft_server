# install and update debian OS
FROM debian:buster
RUN apt-get update && apt-get install -y

# Install mariadb and nginx
RUN  apt -y install wget && apt -y install nginx && nginx -v &&\
apt -y install sendmail \
mariadb-server mariadb-client \
filter openssl \
php7.3-fpm php-curl php-date php-dom php-ftp php-gd php-iconv php-json \
php-mbstring php-mysqli php-posix php-sockets php-tokenizer \
php-xml php-xmlreader php-zip php-simplexml

#  install  PHPmyAdmin
RUN wget https://files.phpmyadmin.net/phpMyAdmin/4.9.3/phpMyAdmin-4.9.3-all-languages.tar.gz && \
    tar -zxvf phpMyAdmin-4.9.3-all-languages.tar.gz && \
    rm phpMyAdmin-4.9.3-all-languages.tar.gz && \
    mv phpMyAdmin-4.9.3-all-languages /var/www/html/phpmyadmin

# copy nginx config 
COPY ./srcs/default /etc/nginx/sites-available/default

#  copy php config
COPY ./srcs/phpmyadmin_config.php \
/var/www/html/phpmyadmin/config.inc.php

# SSL certificate, generate it and sign it
RUN openssl req -x509 -nodes -days 365 -newkey \
rsa:2048 -keyout /etc/ssl/private/localhost.key \
-out /etc/ssl/certs/localhost.crt \
-subj "/C=NL/ST=Noord-Holland/L=Amsterdam/O=Development/CN=localhost"

# Setup PHPMyAdmin config & database (+User)
RUN service mysql stop && service mysql start && \
    mysql < /var/www/html/phpmyadmin/sql/create_tables.sql -u root && \
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' IDENTIFIED BY 'admin' WITH GRANT OPTION;FLUSH PRIVILEGES;" && \
    mysql -e "CREATE DATABASE wordpress;GRANT ALL PRIVILEGES ON wordpress.* TO 'admin'@'localhost' IDENTIFIED BY 'admin';FLUSH PRIVILEGES;" && \
    chmod 660 /var/www/html/phpmyadmin/config.inc.php

# Install Wordpress 
# -p : This option causes Wget to download all the files that are necessary to properly display a given HTML page. 
# This includes such things as inlined images, sounds, and referenced stylesheets.
RUN service mysql start && \
    wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P /var/www/html/ && \
    chmod +x /var/www/html/wp-cli.phar && \
    mv /var/www/html/wp-cli.phar /usr/local/bin/wp && \
    cd /var/www/html/ && \
    wp core download --allow-root && \
    wp config create --dbname=wordpress --dbuser=admin --dbpass=admin --allow-root && \
    wp core install --allow-root --url="/"  --title="confusion is real" --admin_user="admin" --admin_password="admin" --admin_email="panimessage@gmail.com" && \
    mysql -e "USE wordpress;UPDATE wp_options SET option_value='https://localhost/' WHERE option_name='siteurl' OR option_name='home';" && \
    rm /var/www/html/index.nginx-debian.html /var/www/html/readme.html /var/www/html/wp-config-sample.php

# Change PHP upload size, examp. uploading templates for  wordpress
RUN sed -i 's,^post_max_size =.*$,post_max_size = 10M,' /etc/php/7.3/fpm/php.ini && \
    sed -i 's,^upload_max_filesize =.*$,upload_max_filesize = 10M,' /etc/php/7.3/fpm/php.ini

# own webroot by webuser
RUN chown -R www-data:www-data /var/www

#  open ports, 110 sendmail, 443 SSL/HTTPS, 80 Nginx
EXPOSE 110 443 80


# startup script and starting services, keeps container running
COPY /srcs/startup.sh ~/startup.sh
ENTRYPOINT ["/bin/bash", "~/startup.sh"]

# commands to build the container and run it
# docker build -t panini .
# docker run -p 8080:80 -p 443:443 -d --name=server panini
# 