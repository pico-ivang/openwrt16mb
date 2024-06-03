#!/usr/bin/env python3

# скриптец нужен, чтобы по сети рестартовать подвисший 4G TLE USB Router-Wifi

# install google-chrome
# install google-chrome-driver for your version of chrome
# apt-get install python3 python3-pip
# pip3 install selenium


start_url = "http://192.168.43.1:8080/deviceOperation.html"


from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

chrome_options = Options()
# chrome_options.add_argument("--disable-extensions")
# chrome_options.add_argument("--disable-gpu")
#chrome_options.add_argument("--no-sandbox")     # linux only
chrome_options.add_argument("--headless=new")   # for Chrome >= 109
# chrome_options.add_argument("--headless")
# chrome_options.headless = True                # also works
driver = webdriver.Chrome(options=chrome_options)



#implicit wait
driver.implicitly_wait(0.5)

#maximize browser
driver.maximize_window()

#launch URL
driver.get(start_url)

#identify element
#l =driver.find_element_by_xpath("//button[text()='Restart']")
#iBut = driver.find_element(By.XPATH, '//button[text()="Restart"]')

iBut = driver.find_element(By.ID, 'restart')

#perform click
iBut.click()

# this actually performs click
print(iBut)

#print("Page title is: ")
#print(driver.title)

#close browser
driver.quit()

