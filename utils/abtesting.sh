#killall nginx

rm *temp -rf

/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/nginx.conf  
/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/stable.conf 
/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/beta1.conf  
/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/beta2.conf  
/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/beta3.conf  
/home/huang/workspace/tengine-2.1.2/objs/nginx -p `pwd` -c conf/beta4.conf  
