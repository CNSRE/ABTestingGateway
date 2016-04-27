#killall nginx

rm *temp -rf

/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/nginx.conf  -s reload       
/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/stable.conf -s reload
/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/beta1.conf  -s reload
/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/beta2.conf  -s reload
/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/beta3.conf  -s reload
/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/beta4.conf  -s reload
