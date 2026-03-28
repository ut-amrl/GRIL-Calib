#!/bin/bash
 
set -e

# Ros build
source "/opt/ros/humble/setup.bash"
# if [ -f "/root/ros2_livox_ws/install/setup.bash" ]; then
#   source "/root/ros2_livox_ws/install/setup.bash"
# else
#   echo "Warning: /root/ros2_livox_ws/install/setup.bash not found. livox_ros_driver2 overlay is unavailable."
# fi

echo "==============GRIL-Calib ROS2 Docker Env Ready================"

cd /root/ros2_ws

exec "$@"
