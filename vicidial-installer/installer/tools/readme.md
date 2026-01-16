How to Run (Examples)
✅ Fully Automatic (Recommended)
SERVER_IP=46.224.214.202 ./run_smoke_test.sh

🚫 No Auto Install (Strict Mode)
AUTO_INSTALL_DEPS=no SERVER_IP=46.224.214.202 ./run_smoke_test.sh

🖥 GUI Mode (No Xvfb)
HEADLESS=no SERVER_IP=46.224.214.202 ./run_smoke_test.sh

🔕 Skip Selenium Entirely
ENABLE_SELENIUM=no SERVER_IP=46.224.214.202 ./run_smoke_test.sh