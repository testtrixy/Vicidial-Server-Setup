import time
import sys
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.support.ui import Select

SERVER_IP = sys.argv[1]

PHONE_LOGIN = "101"
PHONE_PASS = "test1234"
USER_LOGIN  = "6666"
USER_PASS   = "1234"
CAMPAIGN_ID = "TESTCAMP"

print(f"[SMOKE] Browser test on https://{SERVER_IP}")

options = Options()
options.add_argument("--ignore-certificate-errors")
options.add_argument("--allow-running-insecure-content")

driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

try:
    driver.get(f"https://{SERVER_IP}/agc/vicidial.php")
    time.sleep(2)

    driver.find_element(By.NAME,"phone_login").send_keys(PHONE_LOGIN)
    driver.find_element(By.NAME,"phone_pass").send_keys(PHONE_PASS)
    driver.find_element(By.NAME,"VD_login").send_keys(USER_LOGIN)
    driver.find_element(By.NAME,"VD_pass").send_keys(USER_PASS)

    driver.find_element(By.XPATH,"//input[@type='image']").click()
    time.sleep(3)

    Select(driver.find_element(By.NAME,"VD_campaign")).select_by_value(CAMPAIGN_ID)
    driver.find_element(By.XPATH,"//input[@type='image']").click()

    print("[ACTION] Answer softphone if not auto-answer")
    time.sleep(15)

    page = driver.page_source
    if "conference" not in page:
        driver.save_screenshot("smoke_fail.png")
        sys.exit(1)

    print("[SUCCESS] Agent logged in and audio session active")

finally:
    time.sleep(3)
    driver.quit()
