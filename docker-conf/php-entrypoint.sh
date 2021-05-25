#!/bin/bash

(cd /code/config/ ; php setup.php)
composer require aws/aws-sdk-php
php-fpm