#!/bin/bash
# Boot status display script

MESSAGE="$1"
FRAMEBUFFER="/dev/fb0"

# Clear screen and display SVG with message
/usr/bin/fbi -d $FRAMEBUFFER -T 1 --noverbose --autozoom /home/ndpi-server/ndpi-monitor/Assets/NLC_Logo.png &
FBI_PID=$!

# Wait a moment for fbi to start
sleep 1

# Display message on screen (this is a simplified version)
# In a real implementation, you'd use a more sophisticated text overlay
echo "$MESSAGE" > /dev/tty1

# Keep running until killed
wait $FBI_PID