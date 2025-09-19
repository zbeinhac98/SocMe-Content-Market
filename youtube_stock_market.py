#need to do back end for youtube vs instagram vs tiktok.
#currently have insta scraper set up and youtube scraper seperate. based on user choice for platform
#discerns between which functions to call in stock_graph()
#databasing isn't done though. need new dictionaries in mongodb for each platform.
#then need to change what stock_graph retrieves.
#then need to change where the buy and sell functions pull and do math with
#doesn't discern between the three

#in daily total function need need need to input right platform because right now just says youtube

#uwsgi or gunicorn for production ready server need to implement. 


#think through bank account stuff for deposits and withdrawals
#when people deposit all goes to one bank account money stays there forever
#when people buy ipo shares transfer that exact amount from bank account for all
#to companies private bank account for profit, paying bills, paying salary etc
#when people withdraw comes from big bank account for all
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
import threading
import math
from datetime import datetime, date, timedelta
from flask import Flask, request, jsonify
from flask_cors import CORS
from collections import defaultdict
from decimal import Decimal, getcontext, ROUND_UP, ROUND_DOWN
from pymongo.mongo_client import MongoClient
from pymongo.server_api import ServerApi
import certifi
from bson.decimal128 import Decimal128
import subprocess

import plaid
from plaid.model.link_token_create_request import LinkTokenCreateRequest
from plaid.model.link_token_create_request_user import LinkTokenCreateRequestUser
from plaid.model.item_public_token_exchange_request import ItemPublicTokenExchangeRequest
from plaid.api import plaid_api
from dotenv import load_dotenv
from plaid.model.products import Products
from plaid.model.country_code import CountryCode
from plaid.model.payment_amount import PaymentAmount
from plaid.model.payment_amount_currency import PaymentAmountCurrency
from plaid.model.accounts_get_request import AccountsGetRequest
from plaid.model.transfer_authorization_create_request import TransferAuthorizationCreateRequest
from plaid.model.transfer_create_request import TransferCreateRequest
from plaid.model.transfer_get_request import TransferGetRequest
from plaid.model.transfer_network import TransferNetwork
from plaid.model.transfer_type import TransferType
from plaid.model.transfer_authorization_user_in_request import TransferAuthorizationUserInRequest
from plaid.model.ach_class import ACHClass
from plaid.model.transfer_user_address_in_request import TransferUserAddressInRequest
import json
import os

#Plaid
load_dotenv()
PLAID_CLIENT_ID = os.getenv('PLAID_CLIENT_ID')
PLAID_SECRET = os.getenv('PLAID_SECRET')
PLAID_ENV = os.getenv('PLAID_ENV', 'sandbox')
PLAID_PRODUCTS = os.getenv('PLAID_PRODUCTS', 'transactions').split(',')
PLAID_COUNTRY_CODES = os.getenv('PLAID_COUNTRY_CODES', 'US').split(',')
def empty_to_none(field):
    value = os.getenv(field)
    if value is None or len(value) == 0:
        return None
    return value

host = plaid.Environment.Sandbox

if PLAID_ENV == 'sandbox':
    host = plaid.Environment.Sandbox

if PLAID_ENV == 'production':
    host = plaid.Environment.Production
PLAID_REDIRECT_URI = empty_to_none('PLAID_REDIRECT_URI')

configuration = plaid.Configuration(
    host=host,
    api_key={
        'clientId': PLAID_CLIENT_ID,
        'secret': PLAID_SECRET,
        'plaidVersion': '2020-09-14'
    }
)

api_client = plaid.ApiClient(configuration)
plaid_client = plaid_api.PlaidApi(api_client)

products = []
for product in PLAID_PRODUCTS:
    products.append(Products(product))


# We store the access_token in memory - in production, store it in a secure
# persistent data store.
access_token = None
# The payment_id is only relevant for the UK Payment Initiation product.
# We store the payment_id in memory - in production, store it in a secure
# persistent data store.
payment_id = None
# The transfer_id is only relevant for Transfer ACH product.
# We store the transfer_id in memory - in production, store it in a secure
# persistent data store.
transfer_id = None
# We store the user_token in memory - in production, store it in a secure
# persistent data store.
user_token = None

item_id = None


#MAKE SURE TO START SERVER ONE MIN AFTER AN HOUR SO 6:01 or 2:01
#TEST UPDATES AT MIDNIGHT FOR ACCOUNT TOTALS, DAILY TOTALS, AND SUB AND VIEW COUNTS TO CALCULATE STOCK
#PRICES FOR THE DAY
#KNOWN BUGS:
    #USER BUYS A STOCK THAT THROWS AN ERROR when own a single stock already amount they bought
    #still gets subtracted from available cash to trade. IF NO STOCCKS BOUGHT ALL GOOD
    #if buy a stock but while fetching data stops mid way through purchase still goes through

#mongodb
uri = "mongodb+srv://beinhackerzachary:dHyOYHoJ9in8uijh@contentclustertest01.jvfm2w2.mongodb.net/?retryWrites=true&w=majority&appName=contentclustertest01"
client = MongoClient(uri,
    maxPoolSize=100,          # Max number of connections in pool
    minPoolSize=10,          # Min number of connections to maintain
    connectTimeoutMS=30000,  # 30 seconds timeout on connection attempt
    socketTimeoutMS=30000,   # 30 seconds timeout for operation
    serverSelectionTimeoutMS=30000,  # Wait up to 30 sec for server selection,
    server_api=ServerApi('1'), tlsCAFile=certifi.where())
#plaid

getcontext().prec = 28
buy_pressure = defaultdict(int)
sell_pressure = defaultdict(int)
volume_traded = defaultdict(int)
market_data = defaultdict(lambda: {
    'shares_outstanding': 0,
    'total_value_traded': 0,
    'buy_volume': 0,
    'sell_volume': 0,
    'last_trade_size': 0
})

youtuber_name = ""
username = ""
#stock_dict = {"mrbeast": [Decimal128(str(1))]}
#stock_date_dict = {"mrbeast": ['2025-06-04 09:42:19']}
stock_value = [0]
stock_date = [0]
PORT = 9515

#second number in login dic is how much available to trade, third is how much value user has in stock
#login_dictionary = {"bob": ["smith", "namef", "namel", "bobsmith@gmail.com", "1998-06-09", "address street", "address city", "address state", "address zip", "9142630779", Decimal(str(0)), Decimal(str(50.00)), Decimal(str(0))],
#                    "zbeinhac": ["krabypatty88!", "namf", "naml", "zb@gmail.com", "1997-09-10", "address street", "address city", "address state", "address zip", "9144009671", Decimal(str(0)), Decimal(str(75.00)), Decimal(str(0))]}
#stock_portfolio_dictionary = {"bob": [], "zbeinhac": []}
#cost_basis_dictionary = {"bob": [], "zbeinhac": []}
#daily_stock_total_dictionary = {"bob": [], "zbeinhac": []}
#amount_of_stock_dictionary = {"mrbeast": Decimal128(str(3))}
#account_total_dictionary = {"bob": [Decimal(str(45.00)), Decimal(str(75.00))], "zbeinhac": []}
#youtuber_sub_view_dictionary = {"mrbeast": [10,10]} # format {[name]:[sub count, view count]}
buy_order_book = {} # format {'youtuber name':[(price of stock, shares buying, username, timestamp of purchase)]
sell_order_book = {}
last_checked_date = None

def kill_chromedriver():
    """Forcefully kills all ChromeDriver processes"""
    try:
        # Kill ChromeDriver processes (Linux/macOS)
        subprocess.run(['pkill', '-f', 'chromedriver'], check=False)
        # For Windows, use: subprocess.run(['taskkill', '/f', '/im', 'chromedriver.exe'], check=False)
    except Exception as e:
        print(f"Error killing ChromeDriver: {e}")
        
# Initialize MongoDB collections
def get_db_collection(db_name, collection_name):
    database = client[f"{db_name}_database"]
    return database[f"{collection_name}_collection"]

# Collections
login_collection = get_db_collection("login_dictionary", "login_dictionary")
stock_portfolio_collection = get_db_collection("stock_portfolio_dictionary", "stock_portfolio_dictionary")
cost_basis_collection = get_db_collection("cost_basis_dictionary", "cost_basis_dictionary")
daily_stock_total_collection = get_db_collection("daily_stock_total_dictionary", "daily_stock_total_dictionary")
amount_of_stock_collection = get_db_collection("amount_of_stock_dictionary", "amount_of_stock_dictionary")
account_total_collection = get_db_collection("account_total_dictionary", "account_total_dictionary")
youtuber_sub_view_collection = get_db_collection("youtuber_sub_view_dictionary", "youtuber_sub_view_dictionary")
buy_order_collection = get_db_collection("buy_order_book", "buy_order_book")
sell_order_collection = get_db_collection("sell_order_book", "sell_order_book")
stock_dict_collection = get_db_collection("stock_dict", "stock_dict")
stock_date_dict_collection = get_db_collection("stock_date_dict", "stock_date_dict")
day_collection = get_db_collection("day", "day")
market_data_collection = get_db_collection("market_data", "market_data")
terms_ack_collection = get_db_collection("terms_ack", "terms_ack")
transaction_history_collection = get_db_collection("transaction_history", "transaction_history")
bank_account_collection = get_db_collection("bank_accounts", "bank_accounts")

def sub_count_func(youtuber_name):
#this block is to get total subscriber account based on all channels featuered
#on the main channels homepage
    start_url = "https://youtube.com/@" + youtuber_name
    chrome_options = Options()
    chrome_options.add_argument("--headless=new") # for Chrome >= 109
    driver = webdriver.Chrome(service=Service(port=PORT))
    print("start url", start_url)
    driver.get(start_url)
    time.sleep(4)
    total_sub_count_array = []
    total_sub_count = 0
    header_content = driver.find_element(By.ID, "page-header")
    header_content = header_content.text
    other_channels  = driver.find_elements(By.ID, "channel-info")
    lines = header_content.splitlines()
    for line in lines:
        if "subscribers" in line:
            index = line.index(" ")
            sub_count = line[0:index]
            total_sub_count_array.append(sub_count)
    for num in range(0, len(total_sub_count_array)):
        num = total_sub_count_array[num]
        if "M" in num:
            num_2 = float(num[:-1])
            num_2 = num_2 * 1000000
            total_sub_count = total_sub_count + num_2
        if "K" in num:
            num_2 = float(num[:-1])
            num_2 = num_2 * 1000
            total_sub_count = total_sub_count + num_2
    if total_sub_count < 5000:
        print("here video view func")
        driver.quit()
        kill_chromedriver()
        return 0
    else:
        driver.quit()
        kill_chromedriver()
        return total_sub_count

def video_view_func(youtuber_name):
    #this block gets views of the past 5 videos made by the creator
    total_views_array = []
    date_array = []
    date_numbers = []
    total_views = 0
    chrome_options = Options()
    chrome_options.add_argument("--headless=new") # for Chrome >= 109
    driver = webdriver.Chrome(service=Service(port=PORT))
    video_url = "https://www.youtube.com/@"+youtuber_name+"/videos"
    driver.get(video_url)
    time.sleep(5)
    video_views = driver.find_elements(By.ID, "metadata")
    #video_views = video_views[:5]
    x = 0
    index_ago = 0
    index_view = 0
    vids_date = ""
    vids_2 = ""
    date_space_index = 0
    for vids in video_views:
        vids_2 = vids.text
        if len(vids_2) == 0 or "view" not in vids_2:
            continue
        index = vids_2.index(" ")
        if "and" not in vids_2:
            index_ago = vids_2.index("ago")
            index_view = vids_2.index("view")
            vids_date = vids_2[index_view+6:index_ago-2]
            vids_2 = vids_2[0:index]
            date_space_index = vids_date.index(" ")
        else:
            index_ago = vids_2.index("ago")
            index_view = vids_2.index("view")
            vids_date = vids_2[index_view+6:index_ago-2]
            date_space_index = vids_date.index(" ")
            temp_string = vids_2[index_view-6:index_view-1]
            for i in temp_string:
                
                try:
                    fl = int(i)
                    if type(fl) == int:
                        num_index = temp_string.index(i)
                        break
                except:
                    continue
            
            vids_2 = temp_string[num_index:index_view]
        try:
            date_number = int(vids_date[0:date_space_index])
        except:
            try:
                date_number = int(vids_date[0:date_space_index-1])
            except:
                date_number = int(vids_date[0:date_space_index+1])
        if ("year" in vids_date or "yea" in vids_date) and x == 0:
            driver.quit()
            kill_chromedriver()
            return 0 ,[], []
        if "year" in vids_date or "yea" in vids_date:
            date_numbers.append(-1)
            break
        if "M" in vids_2:
            vid_num = float(vids_2[:-1])
            vid_num = vid_num * 1000000
            total_views = total_views + vid_num
        if "K" in vids_2:
            vid_num = float(vids_2[:-1])
            vid_num = vid_num * 1000
            total_views = total_views + vid_num
        date_array.append(vids_date)
        date_numbers.append(date_number)
        x+= 1        
    
    driver.quit()
    kill_chromedriver()
    return total_views, date_array, date_numbers

def insta_scraper(youtuber_name):
    #this doesn't work. the classes are built dynamically
    #when become a real business need to use instagram graph api
    # this is instas own api about getting data from the app
    start_url ="https://www.instagram.com/" + youtuber_name + "/reels/"
    chrome_options = Options()
    chrome_options.add_argument("--headless=new") # for Chrome >= 109
    driver = webdriver.Chrome(service=Service(port=PORT))
    driver.get("https://www.instagram.com/")
    wait = WebDriverWait(driver, 10)
    username_field = WebDriverWait(driver, 10).until(
    EC.element_to_be_clickable((By.NAME, "username")))
    # Clear and type
    username_field.clear()
    username_field.send_keys("beinhacker.zachary@gmail.com")
    time.sleep(1)
    password_field = WebDriverWait(driver, 10).until(
    EC.element_to_be_clickable((By.NAME, "password")))
    password_field.send_keys("SocmeCM2025!")
    time.sleep(1)
    login_button = WebDriverWait(driver, 10).until(
    EC.element_to_be_clickable((By.CSS_SELECTOR, "button[type='submit']")))
    login_button.click()
    time.sleep(5)
    WebDriverWait(driver, 30).until(
    EC.presence_of_element_located((By.CSS_SELECTOR, "nav, [role='navigation'], .x1iyjqo2")))
    driver.get(start_url)
    WebDriverWait(driver, 20).until(
        EC.presence_of_element_located((By.TAG_NAME, "header"))
    )
    follower_content = driver.find_elements(By.CSS_SELECTOR, "[class='html-span xdj266r x14z9mp xat24cr x1lziwak xexx8yu xyri2b x18d9i69 x1c1uobl x1hl2dhg x16tdsg8 x1vvkbs']")
    num_followers = 0
    followers_text = ""
    x = 0
    for i in follower_content:
        if x == 1:
            followers_text = i.text
            multiplier = followers_text[-1]
            num_followers = float(followers_text[:-1])
            if multiplier == "M":
                num_followers = num_followers * 1000000
                break
            if multiplier == "K":
                num_followers = num_followers * 1000
                break
            if num_followers < 10000:
                num_follwers = 0
                break
        x += 1
        
    print("num_followers", num_followers)
    time.sleep(1)
    reel_content = driver.find_elements(By.CSS_SELECTOR, "[class='_aajy']")
    reel_views_array = []
    for i in reel_content:
        if i.text[-1] == "M":
            views = i.text[:-1]
            reel_views_array.append(float(views)*1000000)
        elif i.text[-1] == "K":
            views = i.text[:-1]
            reel_views_array.append(float(views)*1000)
        else:
            views = i.text[:-1]
            reel_views_array.append(float(views))
    print("reel_views_array", reel_views_array)

    time.sleep(1)
    #need to figure out the class selector to get the number of likes and comments on the reels.
    #it is in the html dont need to go into each individual reel. 
    #reel_likes = driver.find_elements(By.CSS_SELECTOR, "span.x1xlr1w8")
    #print("reel_likes", reel_likes)
    #for i in reel_likes:
    #    print("i.text re", i.text)
    js_explore_script = """
    var reels = document.querySelectorAll("a[href*='/reel/']");
    var results = [];

    for (var i = 0; i < Math.min(3, reels.length); i++) {
        var reel = reels[i];
        var parent = reel.closest('div[class*="_aagv"], div[class*="_aaj-"], div[style*="position: relative"]');
    
        if (!parent) continue;
    
        var engagementData = [];
    
        // Find all spans with the specific class
        var spans = parent.querySelectorAll('span.xdj266r.x14z9mp.xat24cr.x1lziwak.xexx8yu.xyri2b.x18d9i69.x1c1uobl.x1hl2dhg.x16tdsg8.x1vvkbs');
    
        for (var j = 0; j < spans.length; j++) {
            var span = spans[j];
            var text = span.textContent || span.innerText || '';
            text = text.trim();
        
            if (text) {
                engagementData.push({
                    text: text,
                    hasKM: /[KM]/.test(text.toUpperCase()),
                    isLargeNumber: text.replace(/[,.]/g, '').match(/^\d+$/) && parseInt(text.replace(/[,.]/g, '')) > 1000,
                    parentHTML: span.parentElement.outerHTML.substring(0, 200) + '...'
                });
            }
        }
    
        results.push({
            reelIndex: i + 1,
            parentClass: parent.className,
            engagementData: engagementData,
            parentHTML: parent.outerHTML.substring(0, 300) + '...'
        });
    }

    return results;
    """
    reel_data = driver.execute_script(js_explore_script)
    r = 1
    offset = 1
    likes = []
    comments = []
    num = 0
    for data in reel_data:
        print(f"\n=== Reel {data['reelIndex']} ===")
        print(f"Parent class: {data['parentClass']}")
        print("Engagement data found:")
        for engagement in data['engagementData']:
            print(f"  Text: '{engagement['text']}', Has K/M: {engagement['hasKM']}, Large number: {engagement['isLargeNumber']}")
            text = engagement['text']
            if "K" in text:
                text = text[:-1]
                num = float(text) * 1000
            elif "M" in text:
                text = text[:-1]
                num = float(text) * 1000000
            else:
                num = float(text)
            if float(text) not in reel_views_array:
                if r%2 == 1:
                    likes.append(num)
                else:
                    comments.append(num)
                r += 1
    print("likes", likes)
    print("comments", comments)

    time.sleep(500)
    if num_followers < 10000:
        print("here not enough followers")
        driver.quit()
        kill_chromedriver()
        return 0, []
    else:
        driver.quit()
        kill_chromedriver()
        return num_followers, reel_views_array

#calculates the stocks ipo
def stock_price_ipo(youtuber_name):
    count_view_array = []
    total_days = 0
    total_sub_count_ipo = sub_count_func(youtuber_name)
    total_views_ipo, date_array, date_numbers = video_view_func(youtuber_name)
    x = 0
    
    # Calculate total days for timeframe analysis
    for i in date_array:
        if "month" in i or "mont" in i:  # Fixed: combined both conditions
            if date_numbers[x] != 1:
                total_days = total_days + ((30 * date_numbers[x]) - 15)
            elif date_numbers[x] == 1:
                total_days += 30  # Fixed: was totaly_days
        elif "week" in i:
            if date_numbers[x] != 1:
                total_days = total_days + ((7 * date_numbers[x]) - 3.5)
            elif date_numbers[x] == 1:
                total_days += 7
        elif "day" in i:
            total_days = total_days + date_numbers[x]
        elif "hour" in i:
            total_days += 1
        elif "1 da" in i:
            total_days += 1
        x += 1
    
    if total_sub_count_ipo == 0 or total_views_ipo == 0:
        return 0
    
    # Estimate videos and views for the past year
    estimated_videos_past_year = 0
    if date_numbers[-1] == -1:
        estimated_videos_past_year = len(date_numbers) - 1
    else:
        # Calculate months covered by the data
        months_covered = max(1, total_days / 30)
        # Extrapolate to a full year
        estimated_videos_past_year = len(date_numbers) * (12 / months_covered)
        # Ensure reasonable bounds - most active YouTubers upload 50-500 videos per year
        estimated_videos_past_year = max(estimated_videos_past_year, len(date_numbers) * 2)  # At least 2x current sample
    
    # Calculate average views per video from recent performance
    avg_views_per_video = total_views_ipo / len(date_numbers)
    
    # Estimate yearly views based on recent performance
    yearly_views = 0
    if date_numbers[-1] == -1:
        yearly_views = total_views_ipo
    else:
        yearly_views = avg_views_per_video * estimated_videos_past_year
    
    # RPM calculation based on channel size and performance
    base_rpm = 4.5  # Increased from 3.0 to reflect modern YouTube RPMs
    
    # Scale RPM based on subscriber count (bigger channels = better rates)
    if total_sub_count_ipo > 100000000:    # 100M+ subs (MrBeast tier)
        rpm_multiplier = 12.0  # Increased
    elif total_sub_count_ipo > 50000000:   # 50M+ subs
        rpm_multiplier = 9.0   # Increased
    elif total_sub_count_ipo > 20000000:   # 20M+ subs
        rpm_multiplier = 6.5   # Increased
    elif total_sub_count_ipo > 10000000:   # 10M+ subs
        rpm_multiplier = 4.5   # Increased
    elif total_sub_count_ipo > 5000000:    # 5M+ subs
        rpm_multiplier = 3.5   # Increased
    elif total_sub_count_ipo > 1000000:    # 1M+ subs
        rpm_multiplier = 2.8   # Increased
    else:
        rpm_multiplier = 1.5   # Increased from 1.0
    
    # Calculate yearly revenue from YouTube ads
    yearly_ad_revenue = (yearly_views / 1000) * base_rpm * rpm_multiplier
    
    # Add sponsorship/brand deal revenue based on performance and subscriber count
    if (total_sub_count_ipo > 50000000 and avg_views_per_video > 2000000):  # 50M+ subs AND 2M+ avg views
        sponsorship_multiplier = 10.0
    elif (total_sub_count_ipo > 20000000 and avg_views_per_video > 1000000):  # 20M+ subs AND 1M+ avg views
        sponsorship_multiplier = 6
    elif (total_sub_count_ipo > 10000000 and avg_views_per_video > 500000):   # 10M+ subs AND 500k+ avg views
        sponsorship_multiplier = 4
    elif (total_sub_count_ipo > 5000000 and avg_views_per_video > 200000):    # 5M+ subs AND 200k+ avg views
        sponsorship_multiplier = 4
    elif (total_sub_count_ipo > 1000000 and avg_views_per_video > 50000):     # 1M+ subs AND 50k+ avg views
        sponsorship_multiplier = 4.5
    elif avg_views_per_video > 100000:  # High-performing smaller channels
        sponsorship_multiplier = 5
    else:
        sponsorship_multiplier = 2   # Increased from 1.0
    
    # Total yearly revenue (ad revenue + sponsorships)
    total_yearly_revenue = yearly_ad_revenue * sponsorship_multiplier
    
    # Calculate engagement rate for revenue multiple determination
    engagement_rate = total_views_ipo / max(1, total_sub_count_ipo)
    
    # Determine revenue multiple based on channel size and engagement
    # Bigger channels with better engagement get higher multiples (closer to 3x)
    # Smaller channels get lower multiples (closer to 1.5x)
    if (engagement_rate > 0.05 and avg_views_per_video > 2000000):  # High engagement AND high avg views
        revenue_multiple = 2.1
    elif (engagement_rate > 0.03 and avg_views_per_video > 1000000):  # Good engagement AND good avg views
        revenue_multiple = 2.08
    elif (engagement_rate > 0.02 and avg_views_per_video > 500000):   # Decent engagement AND decent avg views
        revenue_multiple = 3.1
    elif (engagement_rate > 0.01 and avg_views_per_video > 200000):   # OK engagement AND OK avg views
        revenue_multiple = 3
    elif avg_views_per_video > 100000:  # At least decent avg views
        revenue_multiple = 2.9
    elif engagement_rate > 0.02:  # Good engagement even with lower views
        revenue_multiple = 2.8
    else:  # Lower performance channels
        revenue_multiple = 1.75  # Increased from 1.5
    
    # Calculate market cap based on yearly revenue multiple
    market_cap = total_yearly_revenue * revenue_multiple
    
    # Ensure minimum viable market cap
    market_cap = max(market_cap, 10000)  # Minimum $10k market cap
    
    # Special case for true mega-performers like MrBeast
    # Only channels that actually generate $1B+ in calculated market cap get the premium treatment
    if market_cap >= 1000000000:  # Only if revenue justifies $1B+ valuation
        market_cap = 1000000000  # Cap at $1B
        stock_price = 100.00
        shares = 10000000  # 10M shares for $1B market cap
    else:
        # Calculate stock price first based on market cap tiers
        if market_cap >= 500000000:  # $500M+ market cap
            stock_price = 75.0 + (25.0 * ((market_cap - 500000000) / 500000000))
        elif market_cap >= 100000000:  # $100M+ market cap
            stock_price = 25.0 + (50.0 * ((market_cap - 100000000) / 400000000))
        elif market_cap >= 50000000:   # $50M+ market cap
            stock_price = 10.0 + (15.0 * ((market_cap - 50000000) / 50000000))
        elif market_cap >= 10000000:   # $10M+ market cap
            stock_price = 2.0 + (8.0 * ((market_cap - 10000000) / 40000000))
        elif market_cap >= 1000000:    # $1M+ market cap
            stock_price = 0.50 + (1.50 * ((market_cap - 1000000) / 9000000))
        else:
            stock_price = 0.10 + (0.40 * (market_cap / 1000000))
        
        # Apply stock price limits
        stock_price = max(0.10, min(stock_price, 100.00))
        
        # Calculate shares based on market cap and stock price
        shares = int(market_cap / stock_price)
    
    # Ensure reasonable share limits
    shares = max(100000, min(shares, 100000000))  # Between 100k and 100M shares
    
    # Recalculate final stock price to match market cap precisely
    final_stock_price = market_cap / shares
    final_stock_price = max(0.10, min(final_stock_price, 100.00))
    
    # Store data
    count_view_array.append(total_sub_count_ipo)
    count_view_array.append(total_views_ipo)
    count_view_array.append(date_array)
    count_view_array.append(date_numbers)
    youtuber_sub_view_collection.insert_one({youtuber_name: count_view_array})
    
    # Store stock price and shares
    stock_dict_collection.insert_one({youtuber_name: [Decimal128(str(final_stock_price))]})
    stock_date_dict_collection.insert_one({youtuber_name: [datetime.now().strftime('%Y-%m-%d %H:%M:%S')]})
    amount_of_stock_collection.insert_one({youtuber_name: Decimal128(str(shares))})
    
    # Handle owner portfolio
    owner_array = stock_portfolio_collection.find_one({"owner": {"$exists": True, "$ne": []}})
    if owner_array:
        owner_array = owner_array["owner"]
        owner_array.append(youtuber_name)
        owner_array.append(Decimal128(str(shares)))
        stock_portfolio_collection.update_one(
            {"owner": {"$exists": True}}, 
            {"$set": {"owner": owner_array}}
        )
    else:
        owner_array = [youtuber_name, Decimal128(str(shares))]
        stock_portfolio_collection.insert_one({"owner": owner_array})
    
    # Debug info
    final_market_cap = final_stock_price * shares
    print(f"Debug - {youtuber_name}:")
    print(f"  Subs: {total_sub_count_ipo:,}, Recent Views: {total_views_ipo:,}")
    print(f"  Avg Views/Video: {avg_views_per_video:,.0f}")
    print(f"  Estimated Yearly Views: {yearly_views:,.0f}")
    print(f"  Yearly Ad Revenue: ${yearly_ad_revenue:,.2f}")
    print(f"  Total Yearly Revenue: ${total_yearly_revenue:,.2f}")
    print(f"  Revenue Multiple: {revenue_multiple}x")
    print(f"  Calculated Market Cap: ${market_cap:,.2f}")
    print(f"  Stock Price: ${final_stock_price:.2f}, Shares: {shares:,}")
    print(f"  Final Market Cap: ${final_market_cap:,.2f}")
    print(f"  Engagement Rate: {engagement_rate:.4f}")
    
    return max(final_stock_price, 0.10)

def stock_price_ipo_insta(youtuber_name):
    num_followers, reel_views_array = insta_scraper(youtuber_name)
    #NEED TO ADD THE REST OF THE ipo function pricing
    if num_followers == 0:
        return 0
    avg_views_reels = sum(reel_views_array)/ len(reel_views_array)
    print("num_followers fool", num_followers)
    print("avg_view_reels", avg_views_reels)
    #p = (num of followers x follower value rate) + (average view per reel * view value rate)
    #p = num_followers + (avg_views_reels)

def calculate_new_price(youtuber_name, transaction_type, amount, shares_traded):
    """
    Calculate new price after transaction based on:
    - Current fundamentals (same as IPO logic)
    - Market depth and liquidity
    - Trade direction (buy/sell)
    - Trade size impact
    """
    # Get current market data
    current_data = market_data_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})[youtuber_name]
    current_price = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    if youtuber_name in current_price:
        current_price = current_price[youtuber_name]
        current_price = current_price[-1]  
    else:
        current_price = stock_price_ipo(youtuber_name, selected_platform)
    
    current_price = Decimal(str(current_price))
    
    # 1. Calculate fundamental value using same logic as IPO function
    count_view_array = youtuber_sub_view_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})[youtuber_name]
    total_sub_count_ipo = count_view_array[0]
    total_views_ipo = count_view_array[1]
    date_array = count_view_array[2]
    date_numbers = count_view_array[3]
    
    # Calculate total days (same as IPO)
    total_days = 0
    x = 0
    for i in date_array:
        if "month" in i or "mont" in i:
            if date_numbers[x] != 1:
                total_days = total_days + ((30 * date_numbers[x]) - 15)
            elif date_numbers[x] == 1:
                total_days += 30
        elif "week" in i:
            if date_numbers[x] != 1:
                total_days = total_days + ((7 * date_numbers[x]) - 3.5)
            elif date_numbers[x] == 1:
                total_days += 7
        elif "day" in i:
            total_days = total_days + date_numbers[x]
        elif "hour" in i:
            total_days += 1
        elif "1 da" in i:
            total_days += 1
        x += 1
    
    # Estimate videos and views for the past year (same as IPO)
    estimated_videos_past_year = 0
    if date_numbers[-1] == -1:
        estimated_videos_past_year = len(date_numbers) - 1
    else:
        months_covered = max(1, total_days / 30)
        estimated_videos_past_year = len(date_numbers) * (12 / months_covered)
        estimated_videos_past_year = max(estimated_videos_past_year, len(date_numbers) * 2)
    
    # Calculate average views per video
    avg_views_per_video = total_views_ipo / len(date_numbers)
    
    # Estimate yearly views
    yearly_views = 0
    if date_numbers[-1] == -1:
        yearly_views = total_views_ipo
    else:
        yearly_views = avg_views_per_video * estimated_videos_past_year
    
    # RPM calculation (same as IPO)
    base_rpm = 4.5
    
    # Scale RPM based on subscriber count
    if total_sub_count_ipo > 100000000:
        rpm_multiplier = 12.0
    elif total_sub_count_ipo > 50000000:
        rpm_multiplier = 9.0
    elif total_sub_count_ipo > 20000000:
        rpm_multiplier = 6.5
    elif total_sub_count_ipo > 10000000:
        rpm_multiplier = 4.5
    elif total_sub_count_ipo > 5000000:
        rpm_multiplier = 3.5
    elif total_sub_count_ipo > 1000000:
        rpm_multiplier = 2.8
    else:
        rpm_multiplier = 1.5
    
    # Calculate yearly revenue
    yearly_ad_revenue = (yearly_views / 1000) * base_rpm * rpm_multiplier
    
    # Add sponsorship revenue (same as IPO)
    if (total_sub_count_ipo > 50000000 and avg_views_per_video > 2000000):
        sponsorship_multiplier = 10.0
    elif (total_sub_count_ipo > 20000000 and avg_views_per_video > 1000000):
        sponsorship_multiplier = 6
    elif (total_sub_count_ipo > 10000000 and avg_views_per_video > 500000):
        sponsorship_multiplier = 4
    elif (total_sub_count_ipo > 5000000 and avg_views_per_video > 200000):
        sponsorship_multiplier = 4
    elif (total_sub_count_ipo > 1000000 and avg_views_per_video > 50000):
        sponsorship_multiplier = 4.5
    elif avg_views_per_video > 100000:
        sponsorship_multiplier = 5
    else:
        sponsorship_multiplier = 2
    
    total_yearly_revenue = yearly_ad_revenue * sponsorship_multiplier
    
    # Calculate engagement rate and revenue multiple (same as IPO)
    engagement_rate = total_views_ipo / max(1, total_sub_count_ipo)
    
    if (engagement_rate > 0.05 and avg_views_per_video > 2000000):
        revenue_multiple = 2.1
    elif (engagement_rate > 0.03 and avg_views_per_video > 1000000):
        revenue_multiple = 2.08
    elif (engagement_rate > 0.02 and avg_views_per_video > 500000):
        revenue_multiple = 3.1
    elif (engagement_rate > 0.01 and avg_views_per_video > 200000):
        revenue_multiple = 3
    elif avg_views_per_video > 100000:
        revenue_multiple = 2.9
    elif engagement_rate > 0.02:
        revenue_multiple = 2.8
    else:
        revenue_multiple = 1.75
    
    # Calculate fundamental market cap
    fundamental_market_cap = total_yearly_revenue * revenue_multiple
    fundamental_market_cap = max(fundamental_market_cap, 10000)
    
    # Get current shares outstanding
    shares_outstanding = float(Decimal(str(current_data['shares_outstanding'])))
    
    # Calculate fundamental stock price
    fundamental_stock_price = fundamental_market_cap / shares_outstanding
    fundamental_stock_price = max(0.10, min(fundamental_stock_price, 100.00))
    fundamental_stock_price = Decimal(str(fundamental_stock_price))
    
    # 2. Calculate market impact based on trade size and liquidity
    total_value_traded = Decimal(str(current_data['total_value_traded']))
    market_depth = total_value_traded / max(1, Decimal(str(shares_outstanding)))
    
    # Calculate liquidity ratio (how big this trade is relative to typical market activity)
    trade_value = Decimal(str(amount))
    liquidity_ratio = trade_value / max(1, market_depth)
    
    # Price impact increases with larger trades relative to market liquidity
    # Buys push price up, sells push price down
    if transaction_type == 'buy':
        # Buying creates upward pressure
        price_impact_factor = Decimal(str(0.015)) * liquidity_ratio  # 1.5% impact per liquidity unit
    else:  # sell
        # Selling creates downward pressure (typically stronger impact)
        price_impact_factor = -Decimal(str(0.025)) * liquidity_ratio  # 2.5% impact per liquidity unit
    
    # Apply price impact to current price
    market_adjusted_price = current_price * (Decimal(str(1)) + price_impact_factor)
    
    # 3. Combine fundamental value with market dynamics
    # Weight: 70% fundamental, 30% market impact (fundamentals are primary driver)
    fundamental_weight = Decimal(str(0.7))
    market_weight = Decimal(str(0.3))
    
    new_price = (fundamental_stock_price * fundamental_weight) + (market_adjusted_price * market_weight)
    
    # 4. Apply reasonable bounds (max 1% change per transaction to prevent extreme volatility)
    max_change = Decimal(str(0.01))
    max_price = current_price * (Decimal(str(1)) + max_change)
    min_price = current_price * (Decimal(str(1)) - max_change)
    
    # Bound the new price
    bounded_price = min(max_price, max(min_price, new_price))
    
    # 5. Final price constraints
    final_price = max(bounded_price, Decimal(str(0.10)))  # Never below $0.10
    
    # Debug info (optional)
    print(f"Price Update - {youtuber_name}:")
    print(f"  Current Price: ${current_price:.2f}")
    print(f"  Fundamental Price: ${fundamental_stock_price:.2f}")
    print(f"  Market Impact: {price_impact_factor:.4f}")
    print(f"  Trade Size: ${trade_value:.2f}, Liquidity Ratio: {liquidity_ratio:.4f}")
    print(f"  New Price: ${final_price:.2f}")
    
    return max(final_price, 0.10)


def update_market_state(youtuber_name, transaction_type, amount, shares_traded):
    """Update all market tracking metrics after a transaction"""
    amount = Decimal(str(amount))
    shares_traded = Decimal(str(shares_traded))
    #data = market_data[youtuber_name]
    data = market_data_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    if data:
        data  = data[youtuber_name]
    else:
        data = {'total_value_traded': 0,
                'last_trade_size' : 0,
                'last_trade_time' : "",
                'buy_volume' : 0,
                'shares_outstanding' : 0,
                'sell_volume' : 0}
    data['total_value_traded'] = Decimal(str(data['total_value_traded'])) + amount
    data['last_trade_size'] = amount
    data['last_trade_time'] = datetime.now()
    if transaction_type == 'buy':
        data['buy_volume'] = Decimal(str(data['buy_volume'])) + amount
        data['shares_outstanding'] = Decimal(str(data['shares_outstanding'])) + shares_traded
    else:
        data['sell_volume'] = Decimal(str(data['sell_volume'])) + amount
        data['shares_outstanding'] = max(0, Decimal(str(data['shares_outstanding'])) - shares_traded)
    for key in data:
        if key != 'last_trade_time' and data[key] != 0 and not isinstance(data[key], Decimal128):
            data[key] = Decimal128(data[key])
    market_data_collection.update_one({youtuber_name: {"$exists": True}},
                    {"$set": {youtuber_name: data}},
                    upsert=True
                )
def add_buy_order(youtuber_name, price, shares, username, m_l):
    """Add a buy order to the order book"""
    orders_array = buy_order_collection.find_one({youtuber_name: {"$exists": True}})
    sell_order = sell_order_collection.find_one({youtuber_name: {"$exists": True}})
    track = 0
    if not orders_array:
        buy_array = []
        track = 1
    else:
        if youtuber_name not in orders_array:
            buy_array = []
            track = 1
        else:
            buy_array = orders_array[youtuber_name]
            track = 0
        
    
    # Add order with timestamp
    timestamp = datetime.now()
    if len(buy_array) > 0:
        for i in buy_array:
            z = 0
            for y in i:
                if z <= 1:
                    i[z] = Decimal(str(y))
                z += 1

    buy_array.append([price, shares, username, timestamp])
    # Sort buy orders by price (descending highest to lowest) and then by timestamp (ascending)
    print("buy arra to be added to book", buy_array)
    print("end")
    buy_array.sort(key=lambda x: (-x[0], x[3]))
    for i in buy_array:
        x = 0
        for y in i:
            if x <= 1:
                i[x] = Decimal128(y)
            x += 1
    if track == 0:
        buy_order_collection.update_one(
            {youtuber_name: {"$exists": True}},
            {"$set": {youtuber_name: buy_array}}
        )
    else:
        buy_order_collection.insert_one({ youtuber_name: buy_array})
    return match_orders(youtuber_name, "buy")

def add_sell_order(youtuber_name, price, shares, username, m_l):
    """Add a sell order to the order book"""
    orders_array = sell_order_collection.find_one({youtuber_name: {"$exists": True}})
    buy_order = buy_order_collection.find_one({youtuber_name: {"$exists": True}})
    amount_stock_left = amount_of_stock_collection.find_one({youtuber_name: {"$exists": True}})[youtuber_name]
    track = 0
    if not orders_array:
        sell_array = []
        track = 1
    else:
        if youtuber_name not in orders_array:
            sell_array = []
            track = 1
        else:
            sell_array = orders_array[youtuber_name]
            track = 0
    # Add order with timestamp
    timestamp = datetime.now()
    if m_l == "l":
        price = price
    else:
        if buy_order:
            buy_order = buy_order[youtuber_name]
            try:
                buy_order = buy_order[0]
                price = Decimal(str(buy_order[0]))
            except:
                price = price
        else:
            price = price
    sell_array.append([price, shares, username, timestamp])
    print("sell array to be added to book", sell_array)
    print("end")
    if len(sell_array) > 0:
        for i in sell_array:
            z = 0
            for y in i:
                if z <= 1:
                    i[z] = Decimal(str(y))
                z += 1
    # Sort sell orders by price (ascending) and then by timestamp (ascending)
    sell_array.sort(key=lambda x: (x[0], x[3]))
    for i in sell_array:
        x = 0
        for y in i:
            if x <= 1:
                i[x] = Decimal128(y)
            x += 1
    if track == 0:
        sell_order_collection.update_one(
            {youtuber_name: {"$exists": True}},
            {"$set": {youtuber_name: sell_array}}
        )
    else:
        sell_order_collection.insert_one({ youtuber_name: sell_array})
    return match_orders(youtuber_name, "sell")

def match_orders(youtuber_name, message):
    """Match buy and sell orders for a youtuber"""
    matches = []
    buy_order_book_array = buy_order_collection.find_one({youtuber_name:{"$exists": True, "$ne": []}})
    sell_order_book_array = sell_order_collection.find_one({youtuber_name:{"$exists": True, "$ne": []}})
    shares_owner_array = stock_portfolio_collection.find_one({"owner":{"$exists": True, "$ne": []}})
    owner_marker = 0
    if shares_owner_array:
        shares_owner_array = shares_owner_array["owner"]
    else:
        shares_owner_array = []
    shares_owner = 0
    shares_index = 0
    if youtuber_name in shares_owner_array:
        shares_index = shares_owner_array.index(youtuber_name)
        shares_owner = shares_owner_array[shares_index + 1]
    # Check if both order books exist and have orders
    if not buy_order_book_array:
        return []
    
    if not sell_order_book_array:
        return []
    
    if youtuber_name not in buy_order_book_array:
        return []

    if youtuber_name not in sell_order_book_array:
        return []
        
    buy_order_book_array = buy_order_book_array[youtuber_name]
    sell_order_book_array = sell_order_book_array[youtuber_name]
    if len(sell_order_book_array) == 4:
        datetime = sell_order_book_array[-1]
        price = sell_order_book_array[0]
    else:
        recent_sell = sell_order_book_array[0]
        datetime = recent_sell[-1]
        price = recent_sell[0]
    datetime = recent_sell[-1]
    price = recent_sell[0]
    if Decimal(str(shares_owner)) > 0:
        array_owner = [price, shares_owner, "owner", datetime]
        sell_order_book_array.insert(1, array_owner)
    # Continue matching as long as there are orders that can be matched
    #first while condition any buy order for youtuber
    #second while condition any sell orders for that youtuber
    #third while condition if highest buy order price >= to lowest sell order match made.
    popped_orders = []
    index_popped_orders = []
    buy_order_array_unchanged = buy_order_book_array
    mult = 0
    popped_owner_array = []
    while (buy_order_book_array and 
           sell_order_book_array and
           Decimal(str(buy_order_book_array[0][0])) >= Decimal(str(sell_order_book_array[0][0]))):
        # Get the highest buy order and lowest sell order
        buy_order = buy_order_book_array[0]
        sell_order = sell_order_book_array[0]
        buy_price, buy_shares, buy_username, buy_timestamp = buy_order
        sell_price, sell_shares, sell_username, sell_timestamp = sell_order
        buy_price = Decimal(str(buy_price))
        buy_shares = Decimal(str(buy_shares))
        sell_price = Decimal(str(sell_price))
        sell_shares = Decimal(str(sell_shares))
        if buy_username == sell_username:
            # Skip this match - orders remain valid but can't trade with themselves
            index_popped_orders.append(buy_order_array_unchanged.index(buy_order))
            popped_orders.append(buy_order)
            buy_order_book_array.pop(0)
            continue
        seller_portfolio = stock_portfolio_collection.find_one({sell_username:{"$exists": True, "$ne": []}})[sell_username]
        if youtuber_name in seller_portfolio:
            seller_index = seller_portfolio.index(youtuber_name)
            seller_available = Decimal(str(seller_portfolio[seller_index + 1]))
            sell_shares = min(sell_shares, seller_available)
            if sell_shares <= 0:
                sell_order_collection.update_one(
                    {youtuber_name: {"$exists": True}},
                    {"$pop": {youtuber_name: 1}}
                )
                sell_order_book_array.pop(0)
                continue
        
        # Execute at the price of the earliest order [3] is for date
        execution_price = sell_price if sell_timestamp < buy_timestamp else buy_price
        
        # Determine how many shares can be matched
        
        matched_shares = min(buy_shares, sell_shares)
        # Record the match
        match_info = {
            'buy_username': buy_username,
            'sell_username': sell_username,
            'price': execution_price,
            'shares': matched_shares,
            'youtuber_name': youtuber_name,
            'timestamp': datetime.now()
        }
        matches.append(match_info)
        print("matches", matches)
        mult = mult + execution_price * matched_shares
        # Update or remove orders
        if buy_shares > matched_shares:
            # Update buy order with remaining shares
            buy_order_book_array[0] = (Decimal128(buy_price), Decimal128(buy_shares - matched_shares), buy_username, buy_timestamp)
            buy_order_collection.update_one(
                {youtuber_name: {"$exists": True}},
                {"$set": {youtuber_name: buy_order_book_array}}
            )
        else:
            # Remove buy order
            buy_order_book_array.pop(0)
            buy_order_collection.update_one(
                {youtuber_name: {"$exists": True}},
                {"$pop": {youtuber_name: 1}}
            )
            
        if sell_shares > matched_shares:
            # Update sell order with remaining shares
            sell_order_book_array[0] = (Decimal128(sell_price), Decimal128(sell_shares - matched_shares), sell_username, sell_timestamp)
            sell_order_collection.update_one(
                {youtuber_name: {"$exists": True}},
                {"$set": {youtuber_name: sell_order_book_array}}
            )
        else:
            # Remove sell order
            name = sell_order_book_array[0]
            name = name[2]
            if name == "owner":
                popped_owner_array.append(sell_order_book_array[0])
            sell_order_book_array.pop(0)
            sell_order_collection.update_one(
                {youtuber_name: {"$exists": True}},
                {"$pop": {youtuber_name: 1}}
            )
    #if len(popped_owner_array) > 0:
        #sell_order_book_array.insert(0, popped_owner_array[0])
    print("popped_owner_array",  popped_owner_array)
    for i in sell_order_book_array:
        print("i", i)
        if "owner" in i:
            print("owner here")
            owner_shares_left = i[1]
            print("owner_shares_left", owner_shares_left)
            owner_marker = 1
            if Decimal(str(owner_shares_left)) > 0:
                shares_owner_array[shares_index + 1] = owner_shares_left
            else:
                shares_owner_array.pop(shares_index)
                shares_owner_array.pop(shares_index)
            if len(shares_owner_array) != 0:
                new_shares = Decimal(str(shares_owner_array[shares_index + 1]))
                str_shares = str(new_shares)
                if '.' in str_shares:
                    decimal_places = len(str(new_shares).split('.')[-1])
                    if decimal_places >= 24:
                        new_shares = round_owner_shares(new_shares)
                shares_owner_array[shares_index + 1] = Decimal128(new_shares)
                owner_shares_left = Decimal128(new_shares)
            stock_portfolio_collection.update_one(
                {"owner": {"$exists": True}},
                {"$set": {"owner": shares_owner_array}}
            )
            amount_of_stock_collection.update_one(
                {youtuber_name: {"$exists": True}},
                {"$set": {youtuber_name: owner_shares_left}}
            )
            index = sell_order_book_array.index(i)
            sell_order_book_array.pop(index)
            break
    if len(popped_owner_array) > 0:
        shares_owner_array.pop(shares_index)
        shares_owner_array.pop(shares_index)
        stock_portfolio_collection.update_one(
            {"owner": {"$exists": True}},
            {"$set": {"owner": shares_owner_array}}
        )
        amount_of_stock_collection.update_one(
            {youtuber_name: {"$exists": True}},
            {"$set": {youtuber_name: 0}}
        )
    sell_order_collection.update_one(
        {youtuber_name: {"$exists": True}},
        {"$set": {youtuber_name: sell_order_book_array}}
    )
    z = 0
    for i in popped_orders:
        buy_order_book_array.insert(index_popped_orders[z], i)
        z += 1
    buy_order_collection.update_one(
        {youtuber_name: {"$exists": True}},
        {"$set": {youtuber_name: buy_order_book_array}}
    )

    # Process the matches
    buy_amount_history = 0
    history_x = 0
    history_array_buy = []
    print("message", message)
    buy_username_history = ""
    sell_username_history = ""
    if message == "buy":
        for match in matches:
            buy_username_history = match["buy_username"]
            sell_username_history = match["sell_username"]
            if history_x == 0:
                history_array_buy = transaction_history_collection.find_one({buy_username_history: {"$exists": True}})[buy_username_history]
            history_array_sell = transaction_history_collection.find_one({sell_username_history: {"$exists": True}})[sell_username_history]
            execution_price_history = match["price"]
            matched_shares_history = match["shares"]
            buy_amount_history = buy_amount_history + (execution_price_history * matched_shares_history)
            history_array_sell.append([datetime.now().strftime('%Y-%m-%d'), "sell", youtuber_name, Decimal128(execution_price_history * matched_shares_history)])
            print("history_array_sell 1", history_array_sell)
            transaction_history_collection.update_one(
                {sell_username_history: {"$exists": True}},
                {"$set": {sell_username_history: history_array_sell}},
                upsert=True
            )
            history_x += 1
        if buy_amount_history != 0:
            history_array_buy.append([datetime.now().strftime('%Y-%m-%d'), "buy", youtuber_name, Decimal128(str(buy_amount_history))])
            print("history_array_buy 1", history_array_buy)
            transaction_history_collection.update_one(
                {buy_username_history: {"$exists": True}},
                {"$set": {buy_username_history: history_array_buy}},
                upsert=True
            )
    sell_amount_history = 0
    history_y = 0
    history_array_sell = []
    buy_username_history = ""
    sell_username_history = ""
    if message == "sell":
        for match in matches:
            buy_username_history = match["buy_username"]
            sell_username_history = match["sell_username"]
            history_array_buy = transaction_history_collection.find_one({buy_username_history: {"$exists": True}})[buy_username_history]
            if history_y == 0:
                history_array_sell = transaction_history_collection.find_one({sell_username_history: {"$exists": True}})[sell_username_history]
            execution_price_history = match["price"]
            matched_shares_history = match["shares"]
            sell_amount_history = sell_amount_history + (execution_price_history * matched_shares_history)
            if sell_amount_history != 0:
                history_array_buy.append([datetime.now().strftime('%Y-%m-%d'), "buy", youtuber_name, Decimal128(execution_price_history * matched_shares_history)])
                print("history_array_buy 2", history_array_buy)
                transaction_history_collection.update_one(
                    {buy_username_history: {"$exists": True}},
                    {"$set": {buy_username_history: history_array_buy}},
                    upsert=True
                )
            history_y += 1
        if sell_amount_history != 0:
            history_array_sell.append([datetime.now().strftime('%Y-%m-%d'), "buy", youtuber_name, Decimal128(str(sell_amount_history))])
            print("history_array_sell 1", history_array_sell)
            transaction_history_collection.update_one(
                {sell_username_history: {"$exists": True}},
                {"$set": {sell_username_history: history_array_sell}},
                upsert=True
            )
            #if sell_amount_history == 0:
            #    history_array_sell.append([datetime.now().strftime('%Y-%m-%d'), "sell", youtuber_name, sell_amount_history])
            #else:
            #    history_array_sell.append([datetime.now().strftime('%Y-%m-%d'), "sell", youtuber_name, Decimal128(sell_amount_history)])
            #print("history_array_sell 2", history_array_sell)
            #transaction_history_collection.update_one(
            #    {sell_username_history: {"$exists": True}},
            #    {"$set": {buy_username_history: history_array_sell}},
            #    upsert=True
            #)

    if mult > 0:
        daily_stock_gain = daily_stock_total_collection.find_one({buy_username:{"$exists": True, "$ne": []}})
        if daily_stock_gain:
            print("daily_stock_gain", daily_stock_gain)
            print("youtuber_name", youtuber_name)
            daily_stock_gain = daily_stock_gain[buy_username]
            if youtuber_name not in daily_stock_gain:
                print("here I go again on my own")
                daily_stock_gain.append(youtuber_name)
                daily_stock_gain.append(Decimal128(mult))
                daily_stock_total_collection.update_one(
                    {buy_username: {"$exists": True}},
                    {"$set": {buy_username: daily_stock_gain}}
                )
        else:
            print("here I go again on my own2")
            daily_stock_gain = []
            daily_stock_gain.append(youtuber_name)
            daily_stock_gain.append(Decimal128(mult))
            daily_stock_total_collection.update_one(
                {buy_username: {"$exists": True}},
                {"$set": {buy_username: daily_stock_gain}}
            )  
    length = len(matches)
    track = 0
    x = 1
    for match in matches:
        if x == length:
            track = 1
        process_match(match, track, owner_marker)
        x += 1
    return matches


total_amount_array = []
shares_array = []
def process_match(match, track, owner_marker):
    """Process a match between a buy and sell order"""
    buy_username = match['buy_username']
    sell_username = match['sell_username']
    price = match['price']
    shares = match['shares']
    youtuber_name = match['youtuber_name']
    # Calculate total transaction amount
    shares = Decimal(str(shares))
    total_amount = Decimal(str(price)) * Decimal(str(shares))
    total_amount_array.append(total_amount)
    shares_array.append(shares)
    # Update buyer account
    buyer_array = login_collection.find_one({buy_username:{"$exists": True, "$ne": []}})[buy_username]
    buyer_array[-1] = Decimal128(Decimal(str(buyer_array[-1])) + total_amount)  # Total invested
    
    # Update seller account
    if sell_username != "owner":
        seller_array = login_collection.find_one({sell_username:{"$exists": True, "$ne": []}})[sell_username]
        seller_array[-2] = Decimal128(Decimal(str(seller_array[-2])) + total_amount)  # Account total

    login_collection.update_one(
        {buy_username: {"$exists": True}},
        {"$set": {buy_username: buyer_array}}
    )
    if sell_username != "owner":
        login_collection.update_one(
            {sell_username: {"$exists": True}},
            {"$set": {sell_username: seller_array}}
        )
    # Update buyer's portfolio
    update_portfolio_for_match(buy_username, youtuber_name, shares, price, 'buy', owner_marker)
    
    # Update seller's portfolio
    if sell_username != "owner":
        update_portfolio_for_match(sell_username, youtuber_name, shares, price, 'sell', owner_marker)
    
    # Update market state and calculate new price
    if track == 1:
        total_amount_update = 0
        shares_total = 0
        for i in total_amount_array:
            total_amount_update += i
        for i in shares_array:
            shares_total += i
            
        update_market_state(youtuber_name, 'trade', total_amount_update, shares_total)
        #new_price = calculate_new_price(youtuber_name, 'trade', total_amount_update, shares_total)
        # Update stock price history
        stock_dict_collection.update_one(
            {youtuber_name: {"$exists": True, "$ne": []}},
            {"$push": {youtuber_name: Decimal128(price)}},
            upsert=True
        )
    
        # Update stock date history
        stock_date_dict_collection.update_one(
            {youtuber_name: {"$exists": True, "$ne": []}},
            {"$push": {youtuber_name: datetime.now().strftime('%Y-%m-%d %H:%M:%S')}},
            upsert=True
        )

#update login dictionary because currently not updating when a sell happens. 
def update_portfolio_for_match(username, youtuber_name, shares, price, action, owner_marker):
    #how cost basis is updated is wrong look at spreadsheet stuff is getting subtracted from shares that shouldnt be
    """Update user portfolio after a trade match"""
    stock_check = stock_portfolio_collection.find_one({username:{"$exists": True, "$ne": []}})
    cost_basis_array = cost_basis_collection.find_one({username:{"$exists": True, "$ne": []}})
    daily_stock_gain = daily_stock_total_collection.find_one({username:{"$exists": True, "$ne": []}})
    mult = 0
    if stock_check:
        if username in stock_check:
            stock_check = stock_check[username]
        else:
            stock_check = []
    else:
        stock_check = []

    if cost_basis_array:
        if username in cost_basis_array:
            cost_basis_array = cost_basis_array[username]
        else:
            cost_basis_array = []
    else:
        cost_basis_array = []

    if daily_stock_gain:
        if username in daily_stock_gain:
            daily_stock_gain = daily_stock_gain[username]
        else:
            daily_stock_gain = []
    else:
        daily_stock_gain = []
    
    if action == 'buy':
        # Update buyer's account (they already paid when placing the order)
        # Update their portfolio to show new shares
        if youtuber_name not in stock_check:
            stock_check.append(youtuber_name)
            str_shares = str(shares)
            if '.' in str_shares:
                decimal_places = len(str(shares).split('.')[-1])
                if decimal_places >= 24:
                    shares = round_user_shares(shares)
            stock_check.append(Decimal128(shares))
            
            # Update cost basis
            cost_basis_array.append(youtuber_name)
            cost_basis_array.append(Decimal128(price))
            cost_basis_array.append(Decimal128(shares))

        else:
            # Add to existing position
            index = stock_check.index(youtuber_name)
            from_array = Decimal(str(stock_check[index + 1]))
            shares = Decimal(str(shares))
            new_shares = from_array + shares
            # Update cost basis - find the right position
            if youtuber_name in cost_basis_array:
                youtuber_index = cost_basis_array.index(youtuber_name)
                # Find the right position to insert the new cost basis
                string_indices = []
                for i, val in enumerate(cost_basis_array):
                    if isinstance(val, str):
                        string_indices.append(i)
                
                if youtuber_index == string_indices[-1]:
                    # Youtuber at end of array
                    cost_basis_array.append(Decimal128(price))
                    cost_basis_array.append(Decimal128(shares))
                    mult = mult + price * shares
                else:
                    # Youtuber in middle of array
                    next_str_idx = string_indices[string_indices.index(youtuber_index) + 1]
                    cost_basis_array.insert(next_str_idx, Decimal128(shares))
                    cost_basis_array.insert(next_str_idx, Decimal128(price))
            

            str_shares = str(new_shares)
            if '.' in str_shares:
                decimal_places = len(str(new_shares).split('.')[-1])
                if decimal_places >= 24:
                    new_shares = round_user_shares(new_shares)
            stock_check[index + 1] = Decimal128(new_shares)
    
        stock_portfolio_collection.update_one(
            {username: {"$exists": True}},
            {"$set": {username: stock_check}}
        )
        cost_basis_collection.update_one(
            {username: {"$exists": True}},
            {"$set": {username: cost_basis_array}}
        )
        
    elif action == 'sell':
        # Update their portfolio to remove sold shares
        if youtuber_name in stock_check:
            index = stock_check.index(youtuber_name)
            from_sell_array = Decimal(str(stock_check[index + 1]))
            shares = Decimal(str(shares))
            new_shares = from_sell_array - shares
            stock_check[index + 1] = Decimal128(new_shares)
            # Remove if all shares sold
            if Decimal(str(stock_check[index + 1])).normalize() <= 0:
                stock_check.pop(index)
                stock_check.pop(index)
                
                # Remove from daily gain
                if youtuber_name in daily_stock_gain:
                    idx = daily_stock_gain.index(youtuber_name)
                    daily_stock_gain.pop(idx)
                    daily_stock_gain.pop(idx)
                
                # Remove from cost basis
                if youtuber_name in cost_basis_array:
                    youtuber_index = cost_basis_array.index(youtuber_name)
                    # Find the right position to remove
                    string_indices = []
                    for i, val in enumerate(cost_basis_array):
                        if isinstance(val, str):
                            string_indices.append(i)
                    if youtuber_index == string_indices[-1]:
                        # Youtuber at end of array
                        cost_basis_array = cost_basis_array[:youtuber_index]
                    else:
                        # Youtuber in middle of array
                        next_str_idx = string_indices[string_indices.index(youtuber_index) + 1]
                        cost_basis_array = cost_basis_array[:youtuber_index] + cost_basis_array[next_str_idx:]
                            
            else:
                # Update cost basis FIFO (First In, First Out)
                if youtuber_name in cost_basis_array:
                    youtuber_index = cost_basis_array.index(youtuber_name)
                    shares_to_remove = Decimal(str(shares))
                    
                    # Find all string indices to determine boundaries
                    string_indices = []
                    for i, val in enumerate(cost_basis_array):
                        if isinstance(val, str):
                            string_indices.append(i)
                    
                    # Find the next stock name after this one to know where to stop
                    current_string_pos = string_indices.index(youtuber_index)
                    if current_string_pos == len(string_indices) - 1:
                        # This is the last stock
                        end_index = len(cost_basis_array)
                    else:
                        # Find the next stock
                        end_index = string_indices[current_string_pos + 1]
                    
                    # Process lots in FIFO order
                    i = youtuber_index + 1  # Start after the stock name
                    while shares_to_remove > 0 and i < end_index:
                        # Each lot consists of [price, shares]
                        if i + 1 >= end_index:
                            break
                            
                        lot_price = cost_basis_array[i]
                        lot_shares = Decimal(str(cost_basis_array[i + 1]))
                        
                        if lot_shares <= shares_to_remove:
                            # Remove entire lot
                            shares_to_remove -= lot_shares
                            cost_basis_array.pop(i)  # Remove price
                            cost_basis_array.pop(i)  # Remove shares (index shifts after first pop)
                            # Update end_index since we removed 2 elements
                            end_index -= 2
                            # Don't increment i since elements shifted
                        else:
                            # Reduce lot size
                            remaining_shares = lot_shares - shares_to_remove
                            cost_basis_array[i + 1] = Decimal128(remaining_shares)
                            shares_to_remove = Decimal('0')
                            break
        if len(stock_check) != 0:
            new_shares = Decimal(str(stock_check[index + 1]))
            str_shares = str(new_shares)
            if '.' in str_shares:
                decimal_places = len(str(new_shares).split('.')[-1])
                if decimal_places >= 24:
                    new_shares = round_owner_shares(new_shares)
            stock_check[index + 1] = Decimal128(new_shares)
        
        stock_portfolio_collection.update_one(
            {username: {"$exists": True}},
            {"$set": {username: stock_check}}
        )
        cost_basis_collection.update_one(
            {username: {"$exists": True}},
            {"$set": {username: cost_basis_array}}
        )
        daily_stock_total_collection.update_one(
            {username: {"$exists": True}},
            {"$set": {username: daily_stock_gain}}
        )

def get_open_orders(message):
    """Get all open orders for a specific user"""
    position = message.find(" ")
    username = message[position + 1:]
    buy_orders = []
    sell_orders = []
    buy_order_book = buy_order_collection.find()
    sell_order_book = sell_order_collection.find()
    # Check buy orders
    if buy_order_book:
        for v in buy_order_book:
            for youtuber_name, orders in v.items():
                if str(youtuber_name) != "_id":
                    for order in orders:
                        price, shares, order_username, timestamp = order
                        total = Decimal(str(price)) * Decimal(str(shares))
                        total = str(math.floor(total*100) / 100)
                        price = str(math.floor(Decimal(str(price))*100) / 100)
                        shares = str(math.floor(Decimal(str(shares))*100) / 100)
                        if order_username == username:
                            buy_orders.append({
                                'youtuber_name': youtuber_name,
                                'price': price,
                                'shares': shares,
                                'timestamp': timestamp,
                                'total': total
                            })
    else:
        buy_orders = []

    # Check sell orders
    if sell_order_book:
        for i in sell_order_book:
            for youtuber_name, orders in i.items():
                if str(youtuber_name) != "_id":
                    for order in orders:
                        price, shares, order_username, timestamp = order
                        total = Decimal(str(price)) * Decimal(str(shares))
                        total = str(math.floor(total*100) / 100)
                        price = str(math.floor(Decimal(str(price))*100) / 100)
                        shares = str(math.floor(Decimal(str(shares))*100) / 100)
                        if order_username == username:
                            sell_orders.append({
                                'youtuber_name': youtuber_name,
                                'price': price,
                                'shares': shares,
                                'timestamp': timestamp,
                                'total': total
                            })
    else:
        sell_orders = []
    
    return buy_orders, sell_orders

def cancel_order(message):
    space_index_array = []
    x = 0
    for i in message:
        if i == " ":
            space_index_array.append(x)
        x += 1
    username = message[space_index_array[0] + 1:space_index_array[1]]
    youtuber_name = message[space_index_array[1] + 1:space_index_array[2]]
    is_buy_order = message[space_index_array[2] + 1:space_index_array[3]]
    timestamp = message[space_index_array[3] + 1:]
    print(is_buy_order)
    try:
        # Parse frontend timestamp (e.g., "Mon, 12 May 2025 19:22:19 GMT")
        frontend_format = "%a, %d %b %Y %H:%M:%S %Z"
        timestamp = datetime.strptime(timestamp, frontend_format)
        
        # Convert to comparable format (remove microseconds and timezone)
        timestamp = timestamp.replace(microsecond=0)
    except ValueError:
        print("Failed to parse frontend timestamp")
        return False
    """Cancel a specific order"""
    if is_buy_order == "true":
        
        buy_order_book = buy_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
        if youtuber_name in buy_order_book:
            buy_order_book = buy_order_book[youtuber_name]
            for i, order in enumerate(buy_order_book):
                price, shares, order_username, order_timestamp = order
                order_timestamp = order_timestamp.replace(microsecond=0)
                if order_username == username and order_timestamp == timestamp:
                    # Remove the order
                    buy_order_book.pop(i)
                    buy_order_collection.update_one(
                        {youtuber_name: {"$exists": True}},
                        {"$set": {youtuber_name: buy_order_book}},
                        upsert=True
                    )
                    # Refund the money
                    array = login_collection.find_one({username: {"$exists": True, "$ne": []}})[username]
                    refund_amount = Decimal(str(price)) * Decimal(str(shares))
                    array[-2] = Decimal128(Decimal(str(array[-2])) + Decimal(str(refund_amount)))
                    login_collection.update_one(
                        {username: {"$exists": True}},
                        {"$set": {username: array}},
                        upsert=True
                    )
                    return True
    else:
        sell_order_book = sell_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
        if youtuber_name in sell_order_book:
            sell_order_book = sell_order_book[youtuber_name]
            for i, order in enumerate(sell_order_book):
                price, shares, order_username, order_timestamp = order
                order_timestamp = order_timestamp.replace(microsecond=0)
                if order_username == username and order_timestamp == timestamp:
                    # Remove the order
                    sell_order_book.pop(i)
                    sell_order_collection.update_one(
                        {youtuber_name: {"$exists": True}},
                        {"$set": {youtuber_name: sell_order_book}},
                        upsert=True
                    )
                    
                    return True
    
    return False

def stock_graph(message):
    username_index = message.find(" ")
    username = message[:username_index]
    youtuber_name_index = message.find(":")+ 2
    youtuber_name = message[youtuber_name_index:]
    selected_platform = message[username_index+1:youtuber_name_index-2]
    print("selected_platform2", selected_platform)
    array = stock_portfolio_collection.find_one({username: {"$exists": True, "$ne": []}})
    stock_dict_youtuber = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    sell_order_book = sell_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    buy_order_book = buy_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    next_buy_price = -1
    next_sell_price = -1
    if buy_order_book:
        buy_order_book_2 = buy_order_book[youtuber_name]
        buy_order_book_2 = buy_order_book_2[0]
        next_sell_price = Decimal(str(buy_order_book_2[0]))
    if sell_order_book:
        sell_order_book_2 = sell_order_book[youtuber_name]
        sell_order_book_2 = sell_order_book_2[0]
        next_buy_price = Decimal(str(sell_order_book_2[0]))
        
    stock_dict_array = []  
    if not array:
        if stock_dict_youtuber:
            stock_dict_array = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
            stock_dict_array = stock_dict_array[youtuber_name]
            x = 0
            for i in stock_dict_array:
                stock_dict_array[x] = str(math.floor(Decimal(str(i))*100) / 100)
                x+=1
            stock_date_dict_array = stock_date_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
            stock_date_dict_array = stock_date_dict_array[youtuber_name]
            if next_buy_price == -1:
                next_buy_price = stock_dict_array[-1]
            if next_sell_price == -1:
                next_sell_price = stock_dict_array[-1]
            return stock_date_dict_array, stock_dict_array, 0, username, next_buy_price, next_sell_price
        
        else:
            print("here stock price ipo")
            p = 0
            if selected_platform == "youtube":
                p = stock_price_ipo(youtuber_name)
            if selected_platform == "instagram":
                p = stock_price_ipo_insta(youtuber_name)
            if p == 0:
                return [0], [0], 0, username, 0, 0
            stock_dict_array = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
            stock_dict_array = stock_dict_array[youtuber_name]
            x = 0
            for i in stock_dict_array:
                stock_dict_array[x] = str(math.floor(Decimal(str(i))*100) / 100)
                x+=1
            stock_date_dict_array = stock_date_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
            stock_date_dict_array = stock_date_dict_array[youtuber_name]
            if next_buy_price == -1:
                next_buy_price = stock_dict_array[-1]
            if next_sell_price == -1:
                next_sell_price = stock_dict_array[-1]
            return stock_date_dict_array, stock_dict_array, 0, username, next_buy_price, next_sell_price
        
    else:
        array = array[username]
        if youtuber_name in array:
            index_a = array.index(youtuber_name) + 1
            amount = stock_dict_youtuber[youtuber_name]
            total_shares_selling = Decimal(str(0))
            if sell_order_book:
                for youtuber_name, orders in sell_order_book.items():
                    if str(youtuber_name) != "_id":
                        for order in orders:
                            price, shares, order_username, timestamp = order
                            if order_username == username:
                                total_shares_selling = total_shares_selling + Decimal(str(shares))
            amount_owned = Decimal(str(amount[-1])) * (Decimal(str(array[index_a])) - total_shares_selling)
            stock_dict_array = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
            stock_dict_array = stock_dict_array[youtuber_name]
            x = 0
            for i in stock_dict_array:
                stock_dict_array[x] = str(math.floor(Decimal(str(i))*100) / 100)
                x+=1
            stock_date_dict_array = stock_date_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
            stock_date_dict_array = stock_date_dict_array[youtuber_name]
            if amount_owned < 0.01 and amount_owned >0:
                amount_owned = Decimal(str(0.01))
            if next_buy_price == -1:
                next_buy_price = stock_dict_array[-1]
            if next_sell_price == -1:
                next_sell_price = stock_dict_array[-1]
            return stock_date_dict_array, stock_dict_array, amount_owned, username, next_buy_price, next_sell_price
        
        if stock_dict_youtuber and youtuber_name not in array:
            stock_dict_array = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
            stock_dict_array = stock_dict_array[youtuber_name]
            x = 0
            for i in stock_dict_array:
                stock_dict_array[x] = str(math.floor(Decimal(str(i))*100) / 100)
                x+=1
            stock_date_dict_array = stock_date_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
            stock_date_dict_array = stock_date_dict_array[youtuber_name]
            if next_buy_price == -1:
                next_buy_price = stock_dict_array[-1]
            if next_sell_price == -1:
                next_sell_price = stock_dict_array[-1]
            return stock_date_dict_array, stock_dict_array, 0, username, next_buy_price, next_sell_price
        if not stock_dict_youtuber:
            p = 0
            if selected_platform == "youtube":
                p = stock_price_ipo(youtuber_name)
            if selected_platform == "instagram":
                p = stock_price_ipo_insta(youtuber_name)
            stock_value[0] = p
            #stock_dict[youtuber_name] = stock_value
            if p != 0:
                stock_dict_collection.update_one(
                    {youtuber_name: {"$exists": True}},
                    {"$set": {youtuber_name: [Decimal128(str(p))]}},
                    upsert=True
                )
                stock_date_dict_collection.update_one(
                    {youtuber_name: {"$exists": True}},
                    {"$set": {youtuber_name: [datetime.today().strftime('%Y-%m-%d %H:%M:%S')]}},
                    upsert=True
                )
                stock_dict_array = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
                stock_dict_array = stock_dict_array[youtuber_name]
                stock_date_dict_array = stock_date_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
                stock_date_dict_array = stock_date_dict_array[youtuber_name]
                x = 0
                for i in stock_dict_array:
                    stock_dict_array[x] = str(math.floor(Decimal(str(i))*100) / 100)
                    x+=1
                if next_buy_price == -1:
                    print("here5")
                    next_buy_price = stock_dict_array[-1]
                if next_sell_price == -1:
                    print("here6")
                    next_sell_price = stock_dict_array[-1]
                return stock_date_dict_array, stock_dict_array, 0, username, next_buy_price, next_sell_price
            if p == 0:
                return [0], [0], 0, username, 0, 0

def round_owner_shares(value):
    """Rounds owner shares down at 24th decimal place"""
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    # Shift decimal point right by 24 places, floor, then shift back
    shifted = value * Decimal('1e24')
    floored = shifted.to_integral_value(rounding=ROUND_DOWN)
    return floored / Decimal('1e24')

def round_user_shares(value):
    """Rounds user shares up at 24th decimal place"""
    if not isinstance(value, Decimal):
        value = Decimal(str(value))
    # Shift decimal point right by 24 places, ceil, then shift back
    shifted = value * Decimal('1e24')
    ceiled = shifted.to_integral_value(rounding=ROUND_UP)
    return ceiled / Decimal('1e24')

def buy_action(message):
    amount = 0
    username = ""
    youtuber_name = ""
    price_limit = 0
    m_l = ""
    if "buy limit" not in message:
        position_1 = message.find(":") + 2
        amount = Decimal(str(message[position_1:]))
        position_2 = message.find(" ")
        username = message[:position_2]
        youtuber_name = message[position_2+5:position_1-2]
        m_l = "m"
    else:
        position_1 = message.find("@")
        position_2 = message.find(":")
        amount = Decimal(str(message[position_2+2 : position_1-1]))
        price_limit = Decimal(str(message[position_1+2:]))
        position_3 = message.find(" ")
        username = message[:position_3]
        position_4 = message.find("limit")
        youtuber_name = message[position_4+6 : position_2]
        m_l = "l"
    array = login_collection.find_one({username: {"$exists": True, "$ne": []}})[username]
    account_total = Decimal(str(array[-2]))
    current_price = 0
    total_stock_owned = Decimal('0')
    stock_dict = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    stock_dict = stock_dict[youtuber_name]
    stock_date_dict = stock_date_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    buy_order_array = buy_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    sell_order_array = sell_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    history_array = transaction_history_collection.find_one({username: {"$exists": True}})[username]
    history_array_owner = transaction_history_collection.find_one({"owner": {"$exists": True}})["owner"]
    # Check if there are available shares in the IPO
    amount_of_stock_left = amount_of_stock_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    if amount_of_stock_left:
        amount_of_stock_left = Decimal(str(amount_of_stock_left[youtuber_name]))
    else:
        amount_of_stock_left = Decimal(str(0))
    # Get current price - use last price if exists, otherwise IPO price
    if stock_dict and m_l == "m" and not sell_order_array:
        current_price = stock_dict[-1]
    elif m_l == "m":
        sell_order_array_temp = sell_order_array[youtuber_name]
        sell_order_array_temp = sell_order_array_temp[0]
        if sell_order_array and amount_of_stock_left == 0:
            current_price = sell_order_array_temp[0]
        elif sell_order_array and amount_of_stock_left > 0:
            if Decimal(str(sell_order_array_temp[0])) > Decimal(str(stock_dict[-1])):
                current_price = stock_dict[-1]
            else:
                current_price = sell_order_array_temp[0]

    if stock_dict and m_l == "l":
        current_price = price_limit
                
    current_price = Decimal(str(current_price))
    shares_requested = amount / current_price
    
    diverge = 0
    if amount > account_total:
        x = 0
        for i in stock_dict:
            stock_dict[x] = Decimal(str(stock_dict[x]))
            x += 1
        stock_check = stock_portfolio_collection.find_one({username: {"$exists": True, "$ne": []}})
        if buy_order_array:
            buy_order_array = buy_order_array[youtuber_name]
            buy_order_array = buy_order_array[0]
            next_sell_price = Decimal(str(buy_order_array[0]))
        else:
            next_sell_price = current_price
        if sell_order_array:
            sell_order_array = sell_order_array[youtuber_name]
            sell_order_array = sell_order_array[0]
            next_buy_price = Decimal(str(sell_order_array[0]))
        else:
            next_buy_price = current_price
        if stock_check:
            stock_check = stock_check[username]
            total_stock_owned = Decimal(str(stock_check[stock_check.index(youtuber_name) + 1])) * current_price
            print("total stock owned1", total_stock_owned)
            return 0, account_total, 0, total_stock_owned, current_price, stock_dict, stock_date_dict[youtuber_name], 0, next_buy_price, next_sell_price
        else:
            return 0, account_total, 0, 0, current_price, stock_dict, stock_date_dict[youtuber_name], 0, next_buy_price, next_sell_price
    
    # If there are IPO shares available, buy directly from IPO
    sell_order_book_array = sell_order_collection.find_one({youtuber_name:{"$exists": True, "$ne": []}})
    if amount_of_stock_left > 0 and not sell_order_book_array and price_limit == 0:
        if shares_requested > amount_of_stock_left:
            diverge = 1
            shares_purchased = Decimal(str(amount_of_stock_left))
            amount = amount_of_stock_left * current_price
        else:
            shares_purchased = shares_requested
        
        # Update account and portfolio
        new_account_total = account_total - amount
        array[-2] = new_account_total
        array[-1] = Decimal(str(array[-1])) + amount  # Total invested
        zed = 0
        for i in array:
            if type(i) != str and i != 0 and not isinstance(i, Decimal128):
                array[zed] = Decimal128(str(array[zed]))
            if i == 0:
                array[zed] = 0
            zed += 1
        login_collection.update_one(
                {username: {"$exists": True}},
                {"$set": {username: array}},
                upsert=True
            )
        
        # Update portfolio
        stock_check = stock_portfolio_collection.find_one({username: {"$exists": True, "$ne": []}})
        cost_basis_array = cost_basis_collection.find_one({username: {"$exists": True, "$ne": []}})
        daily_stock_gain = daily_stock_total_collection.find_one({username: {"$exists": True, "$ne": []}})
        if stock_check:
            stock_check = stock_check[username]
        else:
            stock_check = []
        if cost_basis_array:
            cost_basis_array = cost_basis_array[username]
        else:
            cost_basis_array = []
        if daily_stock_gain:
            daily_stock_gain = daily_stock_gain[username]
        else:
            daily_stock_gain = []
        
        if youtuber_name in stock_check:
            index = stock_check.index(youtuber_name)
            current_shares = Decimal(str(stock_check[index + 1]))
            print("shares_purchased", shares_purchased)
            print("current_shares", current_shares)
            new_shares = Decimal(str(shares_purchased)) + current_shares
            print("new_shares1", new_shares)
            str_new_shares = str(new_shares)
            if '.' in str_new_shares:
                print(".1")
                decimal_places = len(str(new_shares).split('.')[-1])
                if decimal_places >= 24:
                    print(".2")
                    new_shares = round_user_shares(new_shares)
            print("new_shares2", new_shares)
            stock_check[index + 1] = new_shares
        else:
            stock_check.append(youtuber_name)
            str_new_shares = str(shares_purchased)
            new_shares = shares_purchased
            if '.' in str_new_shares:
                print(".1")
                decimal_places = len(str(new_shares).split('.')[-1])
                if decimal_places >= 24:
                    print(".2")
                    new_shares = round_user_shares(new_shares)
            stock_check.append(Decimal(str(new_shares)))
        yed = 0
        for i in stock_check:
            if type(i) != str and i != 0 and not isinstance(i, Decimal128):
                stock_check[yed] = Decimal128(str(stock_check[yed]))
            yed += 1
        stock_portfolio_collection.update_one(
            {username: {"$exists": True}},
            {"$set": {username: stock_check}},
            upsert=True
        )
        owner_array = stock_portfolio_collection.find_one({"owner": {"$exists": True, "$ne": []}})["owner"]
        o_index = owner_array.index(youtuber_name)
        print("stock left owner", Decimal(str(owner_array[o_index+1])))
        print("shares_purchased", shares_purchased)
        current_owner_shares = Decimal(str(owner_array[o_index+1]))
        updated_owner_shares = current_owner_shares - shares_purchased
        print("updated_owner_shares1", updated_owner_shares)
        str_updated_owner_shares = str(updated_owner_shares)
        if '.' in str_updated_owner_shares:
            decimal_places = len(str(updated_owner_shares).split('.')[-1])
            if decimal_places >= 24:
                updated_owner_shares = round_owner_shares(updated_owner_shares)
        print("updated_owner_shares2", updated_owner_shares)
        owner_array[o_index+1] = Decimal128(str(updated_owner_shares))
        if owner_array[o_index+1] == Decimal128(Decimal(str(0))):
            owner_array.pop(o_index)
            owner_array.pop(o_index)
        stock_portfolio_collection.update_one(
            {"owner": {"$exists": True}},
            {"$set": {"owner": owner_array}},
            upsert=True
        )
            
        # Update cost basis
        if youtuber_name in cost_basis_array:
            youtuber_index = cost_basis_array.index(youtuber_name)
            # Find next string index to insert after
            next_str_idx = len(cost_basis_array)
            for i in range(youtuber_index + 1, len(cost_basis_array)):
                if isinstance(cost_basis_array[i], str):
                    next_str_idx = i
                    break
            cost_basis_array.insert(next_str_idx, current_price)
            cost_basis_array.insert(next_str_idx + 1, shares_purchased)
        else:
            cost_basis_array.append(youtuber_name)
            cost_basis_array.append(current_price)
            cost_basis_array.append(shares_purchased)
        h = 0
        for i in cost_basis_array:
            if type(i) != str and i!= 0 and not isinstance(i, Decimal128):
                cost_basis_array[h] = Decimal128(str(cost_basis_array[h]))
            h += 1
        cost_basis_collection.update_one(
            {username: {"$exists": True}},
            {"$set": {username: cost_basis_array}},
            upsert=True
        )
        # Update daily gain
        print("daily_stock_gain", daily_stock_gain)
        if youtuber_name not in daily_stock_gain:
            daily_stock_gain.append(youtuber_name)
            daily_stock_gain.append(Decimal128(amount))
            daily_stock_total_collection.update_one(
                {username: {"$exists": True}},
                {"$set": {username: daily_stock_gain}},
                upsert=True
            )
            
        # Update remaining IPO shares
        #remaining_ipo_shares = max(0, amount_of_stock_left - shares_purchased)
        remaining_ipo_shares = max(0, updated_owner_shares)
        if remaining_ipo_shares != 0:
            remaining_ipo_shares = Decimal128(remaining_ipo_shares)
        amount_of_stock_collection.update_one(
            {youtuber_name: {"$exists": True}},
            {"$set": {youtuber_name: remaining_ipo_shares}},
            upsert=True
        )
        # Update market state and price
        update_market_state(youtuber_name, 'buy', amount, shares_purchased)
        new_price = calculate_new_price(youtuber_name, 'buy', amount, shares_purchased)
        
        # Update price history
        if stock_dict:
            stock_dict.append(new_price)
            r = 0
            for i in stock_dict:
                if type(i) != str and i!= 0 and not isinstance(i, Decimal128):
                    stock_dict[r] = Decimal128(str(stock_dict[r]))
                r += 1
            stock_dict_collection.update_one(
                {youtuber_name: {"$exists": True}},
                {"$set": {youtuber_name: stock_dict}},
                upsert=True
            )
        else:
            stock_dict_collection.insert_one({youtuber_name: [Decimal128(new_price)]})
            
        # Update date history
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        if youtuber_name in stock_date_dict:
            stock_date_dict = stock_date_dict[youtuber_name]
            if isinstance(stock_date_dict, list):
                stock_date_dict.append(current_time)
            else:
                stock_date_dict = [stock_date_dict[youtuber_name], current_time]
            stock_date_dict_collection.update_one(
                {youtuber_name: {"$exists": True}},
                {"$set": {youtuber_name: stock_date_dict}},
                upsert=True
            )
        else:
            stock_date_dict_collection.insert_one({youtuber_name: [current_time]})
            new_price = Decimal(str(new_price))
        total_stock_owned = Decimal(str(stock_check[stock_check.index(youtuber_name) + 1])) * new_price
        x = 0
        for i in stock_dict:
            stock_dict[x] = Decimal(str(stock_dict[x]))
            x += 1
        print("total stock owned2", total_stock_owned)
        if buy_order_array:
            buy_order_array = buy_order_array[youtuber_name]
            buy_order_array = buy_order_array[0]
            next_sell_price = Decimal(str(buy_order_array[0]))
        else:
            next_sell_price = new_price
        if sell_order_array:
            sell_order_array = sell_order_array[youtuber_name]
            sell_order_array = sell_order_array[0]
            next_buy_price = Decimal(str(sell_order_array[0]))
        else:
            next_buy_price = new_price
        history_array.append([datetime.now().strftime('%Y-%m-%d'), "buy", youtuber_name, Decimal128(amount)])
        transaction_history_collection.update_one(
                {username: {"$exists": True}},
                {"$set": {username: history_array}},
                upsert=True
            )
        history_array_owner.append([datetime.now().strftime('%Y-%m-%d'), "sell", youtuber_name, Decimal128(amount)])
        transaction_history_collection.update_one(
                {"owner": {"$exists": True}},
                {"$set": {"owner": history_array_owner}},
                upsert=True
            )
        return 1, new_account_total, amount, total_stock_owned, new_price, stock_dict, stock_date_dict, diverge, next_buy_price, next_sell_price
    else:
        # No IPO shares available, add to order book
        # Reserve the funds
        new_account_total = account_total - amount
        array[-2] = new_account_total
        zed = 0
        for i in array:
            if type(i) != str and i != 0 and not isinstance(i, Decimal128):
                array[zed] = Decimal128(array[zed])
            if i == 0:
                array[zed] = 0
            zed += 1
        login_collection.update_one(
                {username: {"$exists": True}},
                {"$set": {username: array}},
                upsert=True
            )
        
        # Add buy order, matches is an array if matches checks if there is something in the array if not
        #goes to else
        if price_limit != 0:
            current_price = price_limit
            shares_requested = amount / current_price
        print("current price before matches", current_price)
        matches = add_buy_order(youtuber_name, current_price, shares_requested, username, m_l)
        buy_order_array = buy_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
        sell_order_array = sell_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
        stock_check = stock_portfolio_collection.find_one({username: {"$exists": True, "$ne": []}})
        stock_date_dict = stock_date_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})[youtuber_name]
        stock_dict = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})[youtuber_name]
        if stock_check:
            stock_check = stock_check[username]
        else:
            stock_check = []
        x = 0
        for i in stock_dict:
            stock_dict[x] = Decimal(str(stock_dict[x]))
            x += 1
        if matches:
            # If there were immediate matches, get the latest price
            new_price = Decimal(str(stock_dict[-1]))
            
            # Calculate total stock owned after matching
            if stock_check:
                if youtuber_name in stock_check:
                    index = stock_check.index(youtuber_name)
                    total_stock_owned = Decimal(str(stock_check[index + 1])) * Decimal(str(new_price))
            else:
                total_stock_owned = 0

            z = 0
            for i in stock_dict:
                stock_dict[z] = Decimal(str(stock_dict[z]))
                z += 1
            print("total stock owned3", total_stock_owned)
            if buy_order_array:
                buy_order_array = buy_order_array[youtuber_name]
                buy_order_array = buy_order_array[0]
                next_sell_price = Decimal(str(buy_order_array[0]))
            else:
                next_sell_price = new_price
            if sell_order_array:
                sell_order_array = sell_order_array[youtuber_name]
                sell_order_array = sell_order_array[0]
                next_buy_price = Decimal(str(sell_order_array[0]))
            else:
                next_buy_price = new_price
            return 1, new_account_total, amount, total_stock_owned, new_price, stock_dict, stock_date_dict, diverge, next_buy_price, next_sell_price
        else:
            # No matches found - order was added to the book but not executed
            # Return status code indicating pending order (2 for pending)
            if amount_of_stock_left > 0 and price_limit == 0:
                if shares_requested > amount_of_stock_left:
                    diverge = 1
                    shares_purchased = Decimal(str(amount_of_stock_left))
                    amount = amount_of_stock_left * current_price
                else:
                    shares_purchased = shares_requested
                # Update account and portfolio
                new_account_total = account_total - amount
                array[-2] = new_account_total
                array[-1] = Decimal(str(array[-1])) + amount  # Total invested
                zed = 0
                for i in array:
                    if type(i) != str and i != 0 and not isinstance(i, Decimal128):
                        array[zed] = Decimal128(array[zed])
                    zed += 1
                login_collection.update_one(
                        {username: {"$exists": True}},
                        {"$set": {username: array}},
                        upsert=True
                    )
        
                # Update portfolio
                stock_check = stock_portfolio_collection.find_one({username: {"$exists": True, "$ne": []}})
                cost_basis_array = cost_basis_collection.find_one({username: {"$exists": True, "$ne": []}})
                daily_stock_gain = daily_stock_total_collection.find_one({username: {"$exists": True, "$ne": []}})
                if stock_check:
                    stock_check = stock_check[username]
                else:
                    stock_check = []
                if cost_basis_array:
                    cost_basis_array = cost_basis_array[username]
                else:
                    cost_basis_array = []
                if daily_stock_gain:
                    daily_stock_gain = daily_stock_gain[username]
                else:
                    daily_stock_gain = []
        
                if youtuber_name in stock_check:
                    index = stock_check.index(youtuber_name)
                    current_shares = Decimal(str(stock_check[index + 1]))
                    new_shares = Decimal(str(shares_purchased)) + current_shares
                    str_new_shares = str(new_shares)
                    if '.' in str_new_shares:
                        decimal_places = len(str(new_shares).split('.')[-1])
                        if decimal_places >= 24:
                            print("tried")
                            new_shares = round_user_shares(new_shares)
                    stock_check[index + 1] = new_shares
                else:
                    stock_check.append(youtuber_name)
                    interim = round_user_shares(shares_purchased)
                    stock_check.append(Decimal(str(interim)))

                owner_array = stock_portfolio_collection.find_one({"owner": {"$exists": True, "$ne": []}})["owner"]
                o_index = owner_array.index(youtuber_name)
                current_owner_shares = Decimal(str(owner_array[o_index+1]))
                updated_owner_shares = current_owner_shares - shares_purchased
                str_updated_owner_shares = str(updated_owner_shares)
                if '.' in str_updated_owner_shares:
                    decimal_places = len(str(updated_owner_shares).split('.')[-1])
                    if decimal_places >= 24:
                        print("tried2")
                        updated_owner_shares = round_owner_shares(updated_owner_shares)
                owner_array[o_index+1] = Decimal128(str(updated_owner_shares))       
                if owner_array[o_index+1] == Decimal128(Decimal(str(0))):
                    owner_array.pop(o_index)
                    owner_array.pop(o_index)
                stock_portfolio_collection.update_one(
                    {"owner": {"$exists": True}},
                    {"$set": {"owner": owner_array}},
                    upsert=True
                )
                
                yed = 0
                for i in stock_check:
                    if type(i) != str and i != 0 and not isinstance(i, Decimal128):
                        stock_check[yed] = Decimal128(stock_check[yed])
                    yed += 1
                stock_portfolio_collection.update_one(
                    {username: {"$exists": True}},
                    {"$set": {username: stock_check}},
                    upsert=True
                )
            
                # Update cost basis
                if youtuber_name in cost_basis_array:
                    youtuber_index = cost_basis_array.index(youtuber_name)
                    # Find next string index to insert after
                    next_str_idx = len(cost_basis_array)
                    for i in range(youtuber_index + 1, len(cost_basis_array)):
                        if isinstance(cost_basis_array[i], str):
                            next_str_idx = i
                            break
                    cost_basis_array.insert(next_str_idx, current_price)
                    cost_basis_array.insert(next_str_idx + 1, shares_purchased)
                else:
                    cost_basis_array.append(youtuber_name)
                    cost_basis_array.append(current_price)
                    cost_basis_array.append(shares_purchased)
                h = 0
                for i in cost_basis_array:
                    if type(i) != str and i!= 0 and not isinstance(i, Decimal128):
                        cost_basis_array[h] = Decimal128(cost_basis_array[h])
                    h += 1
                cost_basis_collection.update_one(
                    {username: {"$exists": True}},
                    {"$set": {username: cost_basis_array}},
                    upsert=True
                )
                # Update daily gain
                print("daily_stock_gain", daily_stock_gain)
                if youtuber_name not in daily_stock_gain:
                    daily_stock_gain.append(youtuber_name)
                    daily_stock_gain.append(Decimal128(amount))
                    daily_stock_total_collection.update_one(
                        {username: {"$exists": True}},
                        {"$set": {username: daily_stock_gain}},
                        upsert=True
                    )
                print("here buying")
                # Update remaining IPO shares
                #remaining_ipo_shares = max(0, amount_of_stock_left - shares_purchased)
                remaining_ipo_shares = max(0, updated_owner_shares)
                if remaining_ipo_shares != 0:
                    remaining_ipo_shares = round_owner_shares(remaining_ipo_shares)
                    remaining_ipo_shares = Decimal128(remaining_ipo_shares)
                amount_of_stock_collection.update_one(
                    {youtuber_name: {"$exists": True}},
                    {"$set": {youtuber_name: remaining_ipo_shares}},
                    upsert=True
                )
                # Update market state and price
                update_market_state(youtuber_name, 'buy', amount, shares_purchased)
                new_price = calculate_new_price(youtuber_name, 'buy', amount, shares_purchased)
        
                # Update price history
                if stock_dict:
                    stock_dict.append(new_price)
                    r = 0
                    for i in stock_dict:
                        if type(i) != str and i!= 0 and not isinstance(i, Decimal128):
                            stock_dict[r] = Decimal128(stock_dict[r])
                        r += 1
                    stock_dict_collection.update_one(
                        {youtuber_name: {"$exists": True}},
                        {"$set": {youtuber_name: stock_dict}},
                        upsert=True
                    )
                else:
                    stock_dict_collection.insert_one({youtuber_name: [Decimal128(new_price)]})
            
                # Update date history
                current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                stock_date_dict.append(current_time)
                stock_date_dict_collection.update_one(
                    {youtuber_name: {"$exists": True}},
                    {"$set": {youtuber_name: stock_date_dict}},
                    upsert=True
                )

                total_stock_owned = Decimal(str(stock_check[stock_check.index(youtuber_name) + 1])) * new_price
                x = 0
                for i in stock_dict:
                    stock_dict[x] = Decimal(str(stock_dict[x]))
                    x += 1
                print("total stock owned2", total_stock_owned)
                sell_order_book_array = sell_order_book_array[youtuber_name]
                amount_selling = 0
                for i in sell_order_book_array:
                    if username in i:
                        amount_selling = amount_selling + Decimal(str(i[0])) * Decimal(str(i[1]))
                buy_order_book = buy_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})[youtuber_name]
                order_array = []
                for i in buy_order_book:
                    if username in i:
                        order_array.append(i)
                    print("order_array", order_array)   
                sorted_data = sorted(
                    order_array,
                    key=lambda x: (
                    x[-1] if isinstance(x[-1], datetime)
                    else datetime.fromisoformat(x[-1]) if isinstance(x[-1], str)
                    else datetime.min
                    ),
                    reverse=True
                )
                print("sorted data", sorted_data)
                index = buy_order_book.index(sorted_data[0])
                print("index of pop", index)
                print("buy order book ebfore pop", buy_order_book)
                buy_order_book.pop(index)
                print("buy order book after pop", buy_order_book)
                buy_order_collection.update_one(
                    {youtuber_name: {"$exists": True}},
                    {"$set": {youtuber_name:buy_order_book}}
                )
                print("last before return")
                if buy_order_array:
                    buy_order_array = buy_order_array[youtuber_name]
                    buy_order_array = buy_order_array[0]
                    next_sell_price = Decimal(str(buy_order_array[0]))
                else:
                    next_sell_price = new_price
                if sell_order_array:
                    sell_order_array = sell_order_array[youtuber_name]
                    sell_order_array = sell_order_array[0]
                    next_buy_price = Decimal(str(sell_order_array[0]))
                else:
                    next_buy_price = new_price
                print("here")
                history_array.append([datetime.now().strftime('%Y-%m-%d'), "buy", youtuber_name, Decimal128(amount)])
                transaction_history_collection.update_one(
                    {username: {"$exists": True}},
                    {"$set": {username: history_array}},
                    upsert=True
                )
                history_array_owner.append([datetime.now().strftime('%Y-%m-%d'), "sell", youtuber_name, Decimal128(amount)])
                transaction_history_collection.update_one(
                    {"owner": {"$exists": True}},
                    {"$set": {"owner": history_array_owner}},
                    upsert=True
                )
                return 1, new_account_total, amount, total_stock_owned - amount_selling, new_price, stock_dict, stock_date_dict, diverge, next_buy_price, next_sell_price
            
            else:
                price = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})[youtuber_name]
                if youtuber_name in stock_check:
                    stock_check = stock_check
                    total_stock_owned = Decimal(str(stock_check[stock_check.index(youtuber_name) + 1])) * Decimal(str(price[-1]))
                else:
                    total_stock_owned = 0
                print("total stock owned4", total_stock_owned)
                if buy_order_array:
                    buy_order_array = buy_order_array[youtuber_name]
                    buy_order_array = buy_order_array[0]
                    next_sell_price = Decimal(str(buy_order_array[0]))
                else:
                    next_sell_price = Decimal(str(price[-1]))
                if sell_order_array:
                    sell_order_array = sell_order_array[youtuber_name]
                    sell_order_array = sell_order_array[0]
                    next_buy_price = Decimal(str(sell_order_array[0]))
                else:
                    next_buy_price = Decimal(str(price[-1]))
                return 2, new_account_total, amount, total_stock_owned, Decimal(str(price[-1])), stock_dict, stock_date_dict, diverge, next_buy_price, next_sell_price

def sell_action(message):
    amount = 0
    username = ""
    youtuber_name = ""
    price_limit = 0
    array = []
    account_total = 0
    m_l = ""
    if "sell limit" not in message:
        position_1 = message.find(":") + 2
        amount = Decimal(str(message[position_1:]))
        position_2 = message.find(" ")
        username = message[:position_2]
        youtuber_name = message[position_2+6:position_1-2]
        array = login_collection.find_one({username: {"$exists": True, "$ne": []}})[username]
        account_total = Decimal(str(array[-2]))
        m_l = "m"
    else:
        position_1 = message.find("@")
        position_2 = message.find(":")
        amount = Decimal(str(message[position_2+2 : position_1-1]))
        price_limit = Decimal(str(message[position_1+2:]))
        position_3 = message.find(" ")
        username = message[:position_3]
        position_4 = message.find("limit")
        youtuber_name = message[position_4+6 : position_2]
        array = login_collection.find_one({username: {"$exists": True, "$ne": []}})[username]
        account_total = Decimal(str(array[-2]))
        m_l = "l"
    # Get current price
    stock_dict = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    sell_order_book = sell_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    buy_order_array = buy_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    if buy_order_array:
        buy_order_array = buy_order_array[youtuber_name]
        buy_order_array = buy_order_array[0]
        next_sell_price = Decimal(str(buy_order_array[0]))
    else:
        if youtuber_name in stock_dict:
            stock_dict_2 = stock_dict[youtuber_name]
            next_sell_price = Decimal(str(stock_dict_2[-1]))
        else:
            next_sell_price = 0
    if sell_order_book:
        sell_order_book = sell_order_book[youtuber_name]
        sell_order_book = sell_order_book[0]
        next_buy_price = Decimal(str(sell_order_book[0]))
    else:
        if youtuber_name in stock_dict:
            stock_dict_2 = stock_dict[youtuber_name]
            next_buy_price = Decimal(str(stock_dict_2[-1]))
        else:
            next_buy_price = 0
    if youtuber_name in stock_dict:
        stock_dict = stock_dict[youtuber_name]
        print(stock_dict)
    else:
        return 0, account_total, 0, 0, Decimal(str(stock_dict[-1])), [0], ['0000-01-01 00:00:19'], next_buy_price, next_sell_price
    amount = Decimal(str(amount))
    shares_requested = amount / Decimal(str(stock_dict[-1]))
    if "sell limit" in message:
        shares_requested = amount / price_limit
    
    # Check if user owns the stock
    stock_check = stock_portfolio_collection.find_one({username: {"$exists": True, "$ne": []}})
    stock_date_dict = stock_date_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})[youtuber_name]
    if not stock_check:
        x = 0
        for i in stock_dict:
            stock_dict[x] = Decimal(str(stock_dict[x]))
            x += 1
        return 0, account_total, 0, 0, Decimal(str(stock_dict[-1])), stock_dict, stock_date_dict, next_buy_price, next_sell_price
    if stock_check:
        stock_check = stock_check[username]
        if youtuber_name not in stock_check:
            x = 0
            for i in stock_dict:
                stock_dict[x] = Decimal(str(stock_dict[x]))
                x += 1
            return 0, account_total, 0, 0, Decimal(str(stock_dict[-1])), stock_dict, stock_date_dict, next_buy_price, next_sell_price
        
    index = stock_check.index(youtuber_name)
    shares_owned = Decimal(str(stock_check[index + 1]))
    print("shares_owned", shares_owned)
    print("shares requested", shares_requested)
    print("current_price", Decimal(str(stock_dict[-1])))
    amount_of_stock_owned_curr = shares_owned * Decimal(str(stock_dict[-1]))
    print("check1", amount_of_stock_owned_curr - amount)
    print("check1 limit", (shares_owned - shares_requested) * Decimal(str(stock_dict[-1])))
    if "sell limit" not in message:
        if (amount_of_stock_owned_curr - amount < Decimal(str(0.01)) and amount_of_stock_owned_curr - amount > 0) or (amount_of_stock_owned_curr < Decimal(str(0.01)) and amount_of_stock_owned_curr > 0) or amount_of_stock_owned_curr - amount == 0:
            amount = amount_of_stock_owned_curr
            shares_requested = shares_owned
            print("set equal to actual amount no limit")
    else:
        if ((shares_owned - shares_requested) * Decimal(str(stock_dict[-1])) < Decimal(str(0.01)) and (shares_owned - shares_requested) * Decimal(str(stock_dict[-1])) > 0) or shares_owned - shares_requested == 0:
            amount = shares_owned * Decimal(str(stock_dict[-1]))
            shares_requested = shares_owned
            print("set equal to actual amount limit")
        
    # Check if user has enough shares
    total_shares_selling = Decimal(str(0))
    if sell_order_book:
        print(sell_order_book)
        print(len(sell_order_book))
        if len(sell_order_book) > 4:
            for youtuber_name, orders in sell_order_book.items():
                if str(youtuber_name) != "_id":
                    for order in orders:
                        price, shares, order_username, timestamp = order
                        if order_username == username:
                            total_shares_selling = total_shares_selling + Decimal(str(shares))
        else:
            price = sell_order_book[0]
            shares = sell_order_book[1]
            order_username = sell_order_book[2]
            timestamp = sell_order_book[3]
            if username == order_username:
                total_shares_selling = Decimal(str(shares))
            else:
                total_shares_selling = 0
        if shares_owned - total_shares_selling - shares_requested < 0 and amount != round(((shares_owned - total_shares_selling) * Decimal(str(stock_dict[-1]))), 2):
            x = 0
            for i in stock_dict:
                 stock_dict[x] = Decimal(str(stock_dict[x]))
                 x += 1
            total_stock_owned = (shares_owned - total_shares_selling) * Decimal(str(stock_dict[-1]))
            if total_stock_owned < Decimal(str(0.01)) and total_stock_owned >0:
                total_stock_owned = Decimal(str(0.01))
            print("return 1 no")
            return 0, account_total, 0, total_stock_owned, Decimal(str(stock_dict[-1])), stock_dict, stock_date_dict, next_buy_price, next_sell_price
        print("check 1 sell book", (shares_owned - total_shares_selling - shares_requested) * Decimal(str(stock_dict[-1])))
        if (shares_owned - total_shares_selling - shares_requested) * Decimal(str(stock_dict[-1])) < Decimal(str(0.01)):
            amount = (shares_owned - total_shares_selling - shares_requested) * Decimal(str(stock_dict[-1]))
            shares_requested = shares_owned - total_shares_selling
            print("set equal in sell book")
    print("amount", amount)
    print("amount_of_stock_owned_curr", amount_of_stock_owned_curr)
    if "sell limit" not in message:
        if amount > amount_of_stock_owned_curr: 
            x = 0
            for i in stock_dict:
                 stock_dict[x] = Decimal(str(stock_dict[x]))
                 x += 1
            print("total stock owned sell 2", (shares_owned - total_shares_selling) * Decimal(str(stock_dict[-1])))
            total_stock_owned = (shares_owned - total_shares_selling) * Decimal(str(stock_dict[-1]))
            if total_stock_owned < 0.01 and total_stock_owned >0:
                total_stock_owned = Decimal(str(0.01))
            print("return no 2")
            return 0, account_total, 0, total_stock_owned, Decimal(str(stock_dict[-1])), stock_dict, stock_date_dict, next_buy_price, next_sell_price
    else:
        if shares_requested > shares_owned:
            x = 0
            for i in stock_dict:
                 stock_dict[x] = Decimal(str(stock_dict[x]))
                 x += 1
            print("total stock owned sell 2", (shares_owned - total_shares_selling) * Decimal(str(stock_dict[-1])))
            total_stock_owned = (shares_owned - total_shares_selling) * Decimal(str(stock_dict[-1]))
            if total_stock_owned < 0.01 and total_stock_owned >0:
                total_stock_owned = Decimal(str(0.01))
            print("return no 2")
            return 0, account_total, 0, total_stock_owned, Decimal(str(stock_dict[-1])), stock_dict, stock_date_dict, next_buy_price, next_sell_price
    
    
    # Add sell order to the order book
    if "sell limit" not in message:
        #matches = add_sell_order(youtuber_name, Decimal(str(stock_dict[-1])), shares_requested, username, m_l)
        matches = add_sell_order(youtuber_name, Decimal(str(next_sell_price)), shares_requested, username, m_l)
    else:
        matches = add_sell_order(youtuber_name, price_limit, shares_requested, username, m_l)
    stock_date_dict = stock_date_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})[youtuber_name]
    stock_dict = stock_dict_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    stock_check = stock_portfolio_collection.find_one({username: {"$exists": True, "$ne": []}})
    sell_order_book = sell_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    buy_order_array = buy_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
    if matches:
        # If there were immediate matches, get the latest price
        stock_dict = stock_dict[youtuber_name]
        new_price = Decimal(str(stock_dict[-1]))
        # Calculate remaining shares after matching
        shares_owned = 0
        if stock_check:
            if youtuber_name in stock_check:
                stock_check = stock_check[username]
                index = stock_check.index(youtuber_name)
                shares_owned = Decimal(str(stock_check[index + 1]))
        else:
            shares_owned = 0
        
        total_stock_owned = shares_owned * new_price
        # Get updated account total after sell
        account_total = login_collection.find_one({username: {"$exists": True, "$ne": []}})[username]
        account_total = Decimal(str(account_total[-2]))
        x = 0
        for i in stock_dict:
            stock_dict[x] = Decimal(str(stock_dict[x]))
            x += 1
        if total_stock_owned < 0.01 and total_stock_owned >0:
            total_stock_owned = Decimal(str(0.01))
        if buy_order_array:
            buy_order_array = buy_order_array[youtuber_name]
            buy_order_array = buy_order_array[0]
            next_sell_price = Decimal(str(buy_order_array[0]))
        else:
            next_sell_price = new_price
        if sell_order_book:
            sell_order_book = sell_order_book[youtuber_name]
            sell_order_book = sell_order_book[0]
            next_buy_price = Decimal(str(sell_order_book[0]))
        else:
            next_buy_price = new_price
        return 1, account_total, amount, total_stock_owned, new_price, stock_dict, stock_date_dict, next_buy_price, next_sell_price
    else:
        if username in stock_check:
            stock_check = stock_check[username]
            index = stock_check.index(youtuber_name)
            shares_owned = Decimal(str(stock_check[index + 1]))
        else:
            shares_owned = Decimal(str(0))
        sell_order_book = sell_order_collection.find_one({youtuber_name: {"$exists": True, "$ne": []}})
        total_shares_selling = Decimal(str(0))
        if sell_order_book:
            for youtuber_name, orders in sell_order_book.items():
                if str(youtuber_name) != "_id":
                    for order in orders:
                        price, shares, order_username, timestamp = order
                        if order_username == username:
                            total_shares_selling = total_shares_selling + Decimal(str(shares))
        stock_dict = stock_dict[youtuber_name]
        total_stock_owned = (shares_owned * Decimal(str(stock_dict[-1]))) - (total_shares_selling * Decimal(str(stock_dict[-1])))
        x = 0
        for i in stock_dict:
            stock_dict[x] = Decimal(str(stock_dict[x]))
            x += 1
        if total_stock_owned < 0.01 and total_stock_owned >0:
            total_stock_owned = Decimal(str(0.01))
        if buy_order_array:
            buy_order_array = buy_order_array[youtuber_name]
            buy_order_array = buy_order_array[0]
            next_sell_price = Decimal(str(buy_order_array[0]))
        else:
            next_sell_price = Decimal(str(stock_dict[-1]))
        if sell_order_book:
            sell_order_book = sell_order_book[youtuber_name]
            sell_order_book = sell_order_book[0]
            next_buy_price = Decimal(str(sell_order_book[0]))
        else:
            next_buy_price = Decimal(str(stock_dict[-1]))
        return 2, account_total, amount, total_stock_owned, Decimal(str(stock_dict[-1])), stock_dict, stock_date_dict, next_buy_price, next_sell_price

# Display information on order books
def get_market_depth(youtuber_name):
    """Get current buy and sell orders for a youtuber"""
    doc_buy = buy_order_collection.find_one({"youtuber_name": youtuber_name})
    buy_orders = doc_buy[youtuber_name] if doc_buy and youtuber_name in doc_buy else []
    doc_sell = sell_order_collection.find_one({"youtuber_name": youtuber_name})
    sell_orders = doc_sell[youtuber_name] if doc_sell and youtuber_name in doc_sell else []
    
    # Format for presentation
    formatted_buy = []
    for price, shares, username, timestamp in buy_orders:
        formatted_buy.append({
            'price': Decimal(str(price)),
            'shares': Decimal(str(shares)),
            'username': username,
            'timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S')
        })
    
    formatted_sell = []
    for price, shares, username, timestamp in sell_orders:
        formatted_sell.append({
            'price': Decimal(str(price)),
            'shares': Decimal(str(shares)),
            'username': username,
            'timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return {
        'buy_orders': formatted_buy,
        'sell_orders': formatted_sell
    }

def login(message):
    x = 0
    position = []
    for i in message:
        if i == "=":
            position.append(x)
            position[0] = position[0] + 1
        if i == " ":
            position.append(x)
        if i == ":":
            position.append(x)
            position[2] = position[2] + 1
        x += 1
    username = message[position[0]:position[1]]
    password = message[position[2]:]
    account_total_array = account_total_collection.find_one({username: {"$exists": True, "$ne": []}})
    result = login_collection.find_one({username: {"$exists": True, "$ne": []}})
    if result:
        login_dict = result[username]
        if password == login_dict[0]:
            account_total = Decimal(str(login_dict[-1])) + Decimal(str(login_dict[-2]))
            client.close()
            account_total = Decimal(str(account_total))
            y = 0
            account_total_array = account_total_array[username]
            for i in account_total_array:
                account_total_array[y] = Decimal(str(account_total_array[y]))
                y += 1
            return 1, account_total, account_total_array
    else:
        client.close()
        print("didint work caps lock")
        return 0, 0, [0]

def new_account(message):
    print("message new account", message)
    x = 0
    position = []
    info_array = []
    for i in message:
        if i == ":":
            position.append(x)
        if i == " ":
            position.append(x)
        if len(position) >= 10:
            break
        x += 1
    username = message[position[0]+1:position[1]]
    firstname = message[position[2]+1:position[3]]
    lastname = message[position[4]+1:position[5]]
    email = message[position[6]+1:position[7]]
    password = message[position[8]+1:position[9]]
    street_index = message.index("street:")
    city_index = message.index("city:")
    state_index = message.index("state:")
    zipcode_index = message.index("zip:")
    dob_index = message.index("dob:")
    phone_index = message.index("phone:")
    street = message[street_index + 7:city_index-1]
    city = message[city_index + 5:state_index-1]
    state = message[state_index + 6:zipcode_index-1]
    zip_code = message[zipcode_index + 4:dob_index-1]
    dob = message[dob_index + 4:phone_index-1]
    phone = message[phone_index+6:]
    result = login_collection.find_one({username: {"$exists": True}})
    login_dictionary = login_collection.find()
    if result:
        print("didn't work")
        return 0
    for i in login_dictionary:
        for y in i:
            if y != "_id":
                if email in i[y]:
                    return 0
    else:
        info_array.append(password)
        info_array.append(firstname)
        info_array.append(lastname)
        info_array.append(email)
        info_array.append(dob)
        info_array.append(street)
        info_array.append(city)
        info_array.append(state)
        info_array.append(zip_code)
        info_array.append(phone)
        info_array.append(Decimal128(str(10)))
        info_array.append(Decimal128(str(10)))
        info_array.append(Decimal128(str(0)))
        # Create a new client and connect to the server
        
        try:
            login_collection.insert_one({username: info_array})
            stock_portfolio_collection.insert_one({username: []})
            cost_basis_collection.insert_one({username: []})
            daily_stock_total_collection.insert_one({username: []})
            account_total_collection.insert_one({username: [0]})
        except Exception as e:
            print(e)
        return 1

def account_total_fetch(message):
    space_index = message.find(" ") + 1
    username = message[space_index:]
    total = login_collection.find_one({username: {"$exists": True, "$ne": []}})[username]
    stocks_owned_array = stock_portfolio_collection.find_one({username: {"$exists": True, "$ne": []}})
    account_total_array = account_total_collection.find_one({username: {"$exists": True, "$ne": []}})
    acknowledged = terms_ack_collection.find_one({username: {"$exists": True, "$ne": []}})
    total = Decimal(str(total[-2]))
    left_to_use = total
    if stocks_owned_array:
        if username in stocks_owned_array:
            stocks_owned_array = stocks_owned_array[username]
        else:
            stocks_owned_array = []
    else:
        stocks_owned_array = []
    if account_total_array:
        if username in account_total_array:
            account_total_array = account_total_array[username]
        else:
            account_total_array = []
    else:
        account_total_array = []
    x = 0
    for i in stocks_owned_array:
        if x % 2 == 0:
            stock_value = stock_dict_collection.find_one({i: {"$exists": True, "$ne": []}})[i]
        if x % 2 == 1:
            value = Decimal(str(i)) * Decimal(str(stock_value[-1]))
            total = total + value
        x += 1
    y = 0
    total =  Decimal(str(math.floor(total*100) / 100))
    for i in account_total_array:
        account_total_array[y] =  Decimal(str(math.floor(Decimal(str(account_total_array[y]))*100) / 100))
        y += 1
        
    if acknowledged:
        agreed = 1
    else:
        agreed = 0
    return total, account_total_array, agreed, left_to_use

def positions_func(message):
    current_value = []
    stocks_owned = []
    quantity = []
    p_account = []
    cost_basis = []
    current_stock_value = []
    total_gain_stock = []
    daily_gain_stock = []
    space_index = message.find(" ") + 1
    username = message[space_index:]
    stocks_owned_array = stock_portfolio_collection.find_one({username: {"$exists": True, "$ne": []}})
    cost_basis_array = cost_basis_collection.find_one({username: {"$exists": True, "$ne": []}})
    total = login_collection.find_one({username: {"$exists": True, "$ne": []}})[username]
    daily_stock_totals = daily_stock_total_collection.find_one({username: {"$exists": True, "$ne": []}})
    total_2 = Decimal(str(total[-2]))
    x = 0
    if not stocks_owned_array:
        return 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    stocks_owned_array = stocks_owned_array[username]
    cost_basis_array = cost_basis_array[username]
    daily_stock_totals = daily_stock_totals[username]
    for i in stocks_owned_array:
        if x % 2 == 0:
            stocks_owned.append(i)
            stock_dict = stock_dict_collection.find_one({i: {"$exists": True, "$ne": []}})
            stock_value = stock_dict[i]
            current_stock_value.append(Decimal(str(stock_value[-1])))
        if x % 2 == 1:
            quantity.append(Decimal(str(i)))
            value = Decimal(str(i)) * Decimal(str(stock_value[-1]))
            total_2 = total_2 + value
            value_2 = value
            value = Decimal(str(math.floor(value*100) / 100))
            current_value.append(value)
            if (value_2 - Decimal(str(daily_stock_totals[x]))) < 0.001 and (value_2 - Decimal(str(daily_stock_totals[x]))) > (-1)*(0.001):
                daily_gain_stock.append(0)
            else:
                daily_gain_stock.append(value_2 - Decimal(str(daily_stock_totals[x])))
            p_account.append(100*value)
            
        x += 1
            
    for i in range(0, len(p_account)):
        p_account[i] = p_account[i] / total_2

    y = 0
    x = 0
    z = 0
    skips = 0
    running_average = 0
    running_total = 0
    stock_buy_price = 0
    for i in cost_basis_array:
        if x % 2 == 1 and x != 0:
            if type(i) == str:
                running_average = running_average / quantity[y]
                cost_basis.append(running_average)
                running_average = 0
                y += 1
                print("current_value[z]", current_value[z])
                print("running_total", running_total)
                total_gain_stock.append(current_value[z] - running_total)
                running_total = 0
                z += 1
                if (x != len(cost_basis_array) - 1):
                    skips += 1
                    continue
            stock_buy_price = Decimal(str(i))
        if x % 2 == 0 and x !=0 :
            if type(i) == str:
                running_average = running_average / quantity[y]
                cost_basis.append(running_average)
                running_average = 0
                y += 1
                total_gain_stock.append(current_value[z] - running_total)
                running_total = 0
                z += 1
                if (x != len(cost_basis_array) - 1):
                    skips += 1
                    continue
            stock_amount = Decimal(str(i))
            running_average = running_average + (stock_buy_price * stock_amount)
            running_total = stock_buy_price * stock_amount + running_total
        if (type(i) == str and x != 0) or (x + skips == len(cost_basis_array) - 1):
            running_average = running_average / quantity[y]
            cost_basis.append(running_average)
            running_average = 0
            y += 1
            total_gain_stock.append(current_value[z] - running_total)
            running_total = 0
            z += 1

        x += 1

    if len(cost_basis_array) == 3:
        cost_basis[0] = Decimal(str(cost_basis_array[1]))
    sum_stocks = 0
    for i in current_value:
        sum_stocks = i + sum_stocks
    total_gains = sum_stocks - Decimal(str(total[-1]))
    daily_gain = (sum_stocks+Decimal(str(total[-2]))) - Decimal(str(total[-3]))
    total_gains = Decimal(str(math.floor(total_gains*100) / 100))
    daily_gain = Decimal(str(math.floor(daily_gain*100) / 100))
    for w in range(0, len(stocks_owned)):
        current_value[w] = Decimal(str(math.floor(current_value[w]*100) / 100))
        quantity[w] = Decimal(str(math.floor(quantity[w]*100) / 100))
        p_account[w] = Decimal(str(math.floor(p_account[w]*100) / 100))
        cost_basis[w] = Decimal(str(math.floor(cost_basis[w]*100) / 100))
        current_stock_value[w] = Decimal(str(math.floor(current_stock_value[w]*100) / 100))
        total_gain_stock[w] = Decimal(str(math.floor(total_gain_stock[w]*100) / 100))
        daily_gain_stock[w] = Decimal(str(math.floor(daily_gain_stock[w]*100) / 100))
    print("total_gain_stock", total_gain_stock)
    return current_value, stocks_owned, quantity, p_account, cost_basis, total_gains, daily_gain, current_stock_value, total_gain_stock, daily_gain_stock


def daily_total_func():
    threading.Timer(3600.0, daily_total_func).start()
    global last_checked_date
    current_date = datetime.now().date()
    result = day_collection.find_one({"last_checked_date": {"$exists": True, "$ne": []}})
    date = result["last_checked_date"]
    last_checked_date = datetime.strptime(date, "%Y-%m-%d").date()
    
    if last_checked_date is None or current_date > last_checked_date:
        last_checked_date = current_date
        day_collection.update_one(
                    {"last_checked_date": {"$exists": True}},
                    {"$set": {"last_checked_date": str(last_checked_date)}},
                    upsert=True
                )
        # Get all login entries
        login_entries = login_collection.find({})
        
        for login_entry in login_entries:
            for username, dict_value in login_entry.items():
                if username == '_id':
                    continue
                    
                i = username
                x = 0
                amount = Decimal('0')
                array = []
                
                # Get stock portfolio data
                stock_portfolio_entry = stock_portfolio_collection.find_one({i: {"$exists": True}})
                stock_array = stock_portfolio_entry[i] if stock_portfolio_entry else []
                # Get or create daily stock total entry
                daily_total_entry = daily_stock_total_collection.find_one({i: {"$exists": True}})
                daily_total = daily_total_entry[i] if daily_total_entry else []
                # Get account total data
                account_total_entry = account_total_collection.find_one({i: {"$exists": True}})
                account_total_array = account_total_entry[i] if account_total_entry else []
                temp_username = ""
                for y in stock_array:
                    if type(y) == str:
                        stock_value_entry = stock_dict_collection.find_one({y: {"$exists": True}})
                        stock_value_array = stock_value_entry[y] if stock_value_entry else []
                        temp_username = y
                        if y not in daily_total:
                            daily_total.append(y)
                    if x % 2 == 1 and x != 0 and type(y) != str:
                        stock_amount = Decimal(str(y))
                        stock_value = Decimal(str(stock_value_array[-1]))
                        amount = Decimal(str(stock_value * stock_amount))
                        if temp_username not in daily_total:
                            daily_total.append(Decimal128(round(amount, 20)))
                        else:
                            y_username_index = daily_total.index(temp_username)
                            daily_total[y_username_index + 1] = Decimal128(round(amount, 20))
                    x += 1
                # Convert dict_value[-2] to Decimal for arithmetic
                dict_value_minus_2 = Decimal(str(dict_value[-2]))
                dict_value[-3] = Decimal128(str(round((amount + dict_value_minus_2), 20)))
                
                # Update daily stock total dictionary
                daily_stock_total_collection.update_one(
                    {i: {"$exists": True}},
                    {"$set": {i: daily_total}},
                    upsert=True
                )
                
                # Update account total dictionary
                account_total_array.append(dict_value[-3])
                account_total_collection.update_one(
                    {i: {"$exists": True}},
                    {"$set": {i: account_total_array}},
                    upsert=True
                )
                
                # Update login dictionary
                login_collection.update_one(
                    {i: {"$exists": True}},
                    {"$set": {i: dict_value}},
                    upsert=True
                )
                
        # Handle YouTuber subscription/view data
        youtuber_entries = youtuber_sub_view_collection.find({})
        
        for youtuber_entry in youtuber_entries:
            for username, count_view_array in youtuber_entry.items():
                if username == '_id':
                    continue
                    
                i = username
                count_view_array = []
                total_sub_count_ipo = sub_count_func(i)
                total_views_ipo, date_array, date_numbers = video_view_func(i)
                count_view_array.append(total_sub_count_ipo)
                count_view_array.append(total_views_ipo)
                count_view_array.append(date_array)
                count_view_array.append(date_numbers)
                
                youtuber_sub_view_collection.update_one(
                    {i: {"$exists": True}},
                    {"$set": {i: count_view_array}},
                    upsert=True
                )

def settings_func(message):
    space_index = message.index(" ")
    username = message[space_index + 1:]
    result = login_collection.find_one({username: {"$exists": True, "$ne": []}})
    settings_array = result[username]
    settings_array = settings_array[:10]
    settings_array.pop(4)
    print("settings_array", settings_array)
    return settings_array

def change_settings_func(message):
    print("message", message)
    space_index = []
    x = 0
    for i in message:
        if i == " ":
            space_index.append(x)
        x += 1
        if len(space_index) >=3:
            break
    username = message[space_index[0]+1:space_index[1]]
    password = message[space_index[1]+1:space_index[2]]
    street_index = message.index("street:")
    email = message[space_index[2]+1:street_index-1]
    city_index = message.index("city:")
    state_index = message.index("state:")
    zipcode_index = message.index("zip:")
    phone_index = message.index("phone:")
    street = message[street_index + 7:city_index-1]
    city = message[city_index + 5:state_index-1]
    state = message[state_index + 6:zipcode_index-1]
    zip_code = message[zipcode_index + 4:phone_index-1]
    phone = message[phone_index+6:]
    result = login_collection.find_one({username: {"$exists": True, "$ne": []}})
    settings_array = result[username]
    settings_array[0] = password
    settings_array[3] = email
    settings_array[5] = street
    settings_array[6] = city
    settings_array[7] = state
    settings_array[8] = zip_code
    settings_array[9] = phone
    login_collection.update_one(
                    {username: {"$exists": True}},
                    {"$set": {username: settings_array}},
                    upsert=True
                )
    settings_array = settings_array[:10]
    settings_array.pop(4)
    return settings_array

def top_stock():
    total_value_traded = {}
    last_trade_time = {}
    market_data = market_data_collection.find()
    stock_dict = stock_dict_collection.find()
    prices = {}
    for i in market_data:
        for y in i:
            if y != "_id":
                market_info = i[y]
                total_value_traded[y] = Decimal(str(market_info["total_value_traded"]))
                last_trade_time[y] = market_info["last_trade_time"]

    sorted_by_value = dict(sorted(
        total_value_traded.items(),
        key=lambda item: item[1],
        reverse=True
    ))
    sorted_by_time = dict(sorted(
        last_trade_time.items(),
        key=lambda item: item[1],
        reverse=True
    ))
    
    for i in stock_dict:
        for y in i:
            if y != "_id":
                prices[y] = Decimal(str(i[y][-1]))

    sorted_by_price = dict(sorted(
        prices.items(),
        key=lambda item: item[1],
        reverse=True
    ))
    sorted_by_price_low = dict(sorted(
        prices.items(),
        key=lambda item: item[1],
        reverse=False
    ))
    
    if len(sorted_by_value) > 5:
        sorted_by_value = sorted_by_value[0:5]
    if len(sorted_by_time) > 5:
        sorted_by_time = sorted_by_time[0:5]
    if len(sorted_by_price) > 5:
        sorted_by_price = sorted_by_price[0:5]
        sorted_by_price_low = sorted_by_price_low[0:5]
    
    return sorted_by_value, sorted_by_time, sorted_by_price, sorted_by_price_low

def terms_ack(message):
    space_index = message.index(" ")
    username = message[space_index + 1:]
    result = terms_ack_collection.find_one({username: {"$exists": True, "$ne": []}})
    if result:
        return 1
    elif not result and not "check" in message:
        return 0
    if "check" in message:
        terms_ack_collection.insert_one({username: 1})
        return 1

def transaction_history(message):
    space_index = message.index(" ")
    username = message[space_index + 1:]
    history_array = transaction_history_collection.find_one({username: {"$exists": True}})
    transfer_array = []
    buy_sell_array = []
    if history_array:
        history_array = history_array[username]
    else:
        return transfer_array, buy_sell_array

    for i in history_array:
        if i[1] == "withdraw" or i[1] == "deposit":
            i[2] = Decimal(str(i[2]))
            transfer_array.append(i)
        else:
            i[3] = Decimal(str(i[3]))
            buy_sell_array.append(i)

    return transfer_array, buy_sell_array
    
app = Flask(__name__)
CORS(app)
#PLAID FUNCTIONS
@app.route('/api/create_link_token', methods=['POST'])
def create_link_token():
    print("here")
    try:
        # Basic request configuration
        request_data = {
            'products': products,
            'client_name': "Your App Name",
            'country_codes': list(map(lambda x: CountryCode(x), PLAID_COUNTRY_CODES)),
            'language': 'en',
            'user': {
                'client_user_id': str(time.time()),
                'legal_name': "John Doe",
                'email_address': "john.doe@example.com",
                'phone_number': "+14155551234"
            }
        }

        # Optional fields
        if PLAID_REDIRECT_URI:
            request_data['redirect_uri'] = PLAID_REDIRECT_URI
        
        if Products('statements') in products:
            request_data['statements'] = {
                'end_date': date.today(),
                'start_date': date.today()-timedelta(days=30)
            }

        # Create and send request
        request = LinkTokenCreateRequest(**request_data)
        response = plaid_client.link_token_create(request)
        
        print("Successfully created link token")
        return jsonify(response.to_dict())
        
    except plaid.ApiException as e:
        error_msg = f"Plaid API error: {str(e)}"
        print(error_msg)
        return jsonify({"error": error_msg}), 400
    except Exception as e:
        error_msg = f"Unexpected error: {str(e)}"
        print(error_msg)
        return jsonify({"error": error_msg}), 500

@app.route('/api/set_access_token', methods=['POST'])
def get_access_token():
    global access_token
    global item_id
    try:
        # Get JSON data from request instead of form data
        request_data = request.get_json()
        if not request_data or 'public_token' not in request_data:
            return jsonify({'error': 'Missing public_token'}), 400
        
        public_token = request_data['public_token']
        user_id = request_data.get('user_id', '')  # Get user_id if provided
        
        exchange_request = ItemPublicTokenExchangeRequest(
            public_token=public_token
        )
        exchange_response = plaid_client.item_public_token_exchange(exchange_request)
        
        access_token = exchange_response['access_token']
        item_id = exchange_response['item_id']
        
        # Return both access_token and item_id in the response
        return jsonify({
            'access_token': access_token,
            'item_id': item_id,
            'user_id': user_id  # Echo back the user_id for reference
        })
        
    except plaid.ApiException as e:
        error_response = json.loads(e.body)
        print(f"Plaid API error: {error_response}")
        return jsonify({
            'error': error_response.get('error_message', 'Plaid API error'),
            'error_code': error_response.get('error_code'),
            'error_type': error_response.get('error_type')
        }), e.status
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return jsonify({
            'error': 'Internal server error',
            'details': str(e)
        }), 500

@app.route('/api/transfer_authorize', methods=['POST'])
def transfer_authorization():
    try:
        data = request.get_json()
        print(f"Incoming authorization request data: {data}")
        
        if not data:
            client.close()
            return jsonify({'error': 'No data provided'}), 400
            
        access_token = data.get('access_token')
        amount = data.get('amount')
        transfer_type = data.get('type')
        username = data.get('user_id')  # This is the username from FundTransferView
        
        if not all([access_token, amount, transfer_type, username]):
            client.close()
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Query MongoDB using the username as the key
        user_data = login_collection.find_one({username: {"$exists": True}})
        if not user_data:
            client.close()
            return jsonify({'error': f'User {username} not found'}), 404
            
        user_info = user_data[username]
        
        # Get accounts
        try:
            accounts_request = AccountsGetRequest(access_token=access_token)
            accounts_response = plaid_client.accounts_get(accounts_request)
            account = accounts_response['accounts'][0]  # Using first account
        except Exception as e:
            print(f"Error getting accounts: {str(e)}")
            client.close()
            return jsonify({'error': 'Failed to get account information'}), 400
        
        # Create authorization
        try:
            auth_request = TransferAuthorizationCreateRequest(
                access_token=access_token,
                account_id=account['account_id'],
                type=TransferType(transfer_type.lower()),  # 'credit' or 'debit'
                network=TransferNetwork('ach'),
                amount=str(amount),
                ach_class=ACHClass('ppd'),
                user=TransferAuthorizationUserInRequest(
                    legal_name=f"{user_info[1]} {user_info[2]}",  # first + last name
                    email_address=user_info[3],
                    address=TransferUserAddressInRequest(
                        street=user_info[5],
                        city=user_info[6],
                        region=user_info[7],
                        postal_code=user_info[8],
                        country='US'
                    )
                )
            )
            
            response = plaid_client.transfer_authorization_create(auth_request)
            print("Authorization response:", response.to_dict())
            client.close()
            return jsonify({
                'authorization_id': response['authorization']['id'],
                'account_id': account['account_id'],
                'status': 'success'
            })
            
        except plaid.ApiException as e:
            error_response = json.loads(e.body)
            print(f"Plaid API error: {error_response}")
            client.close()
            client.close()
            return jsonify({
                'error': error_response.get('error_message', 'Authorization failed'),
                'code': error_response.get('error_code'),
                'type': error_response.get('error_type')
            }), 400
            
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        client.close()
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/transfer_create', methods=['POST'])
def transfer():
    try:
        print("here 1")
        data = request.get_json()
        print(f"Incoming transfer request data: {data}")
        
        required_fields = ['access_token', 'authorization_id', 'account_id', 'user_id']
        if not all(field in data for field in required_fields):
            return jsonify({'error': 'Missing required fields'}), 400
            
        username = data['user_id']  # This is the username from FundTransferView
        
        # Query MongoDB using the username as the key
        user_data = login_collection.find_one({username: {"$exists": True}})
        history_array = transaction_history_collection.find_one({username: {"$exists": True}})
        if not user_data:
            return jsonify({'error': f'User {username} not found'}), 404
        if not history_array:
            history = []
        else:
            history = history_array[username]
            
        try:
            print("here 2")
            # Set description based on transfer type
            transfer_type = data.get('type', 'credit')
            description = "Deposit" if transfer_type == 'credit' else "Withdrawal"
            
            transfer_request = TransferCreateRequest(
                access_token=data['access_token'],
                authorization_id=data['authorization_id'],
                account_id=data['account_id'],
                description=description
            )
            
            response = plaid_client.transfer_create(transfer_request)
            print("Transfer response:", response.to_dict())
            
            # Convert status to string for JSON serialization AND comparison
            transfer_status = str(response['transfer']['status'])
            print("transfer_status", transfer_status)
            
            # Update user balance if successful - compare string status
            if transfer_status.lower() in ['posted', 'pending']:  # Compare string values
                print("here 3")
                user_array = user_data[username]
                amount = Decimal(response['transfer']['amount'])
                
                # Check transfer type from the request data
                if data.get('type') == 'credit':  # deposit
                    user_array[-2] = Decimal128(Decimal(str(user_array[-2])) + amount)
                    history.append([datetime.now().strftime('%Y-%m-%d'), "deposit", Decimal128(amount)])
                else:  # debit (withdraw)
                    user_array[-2] = Decimal128(Decimal(str(user_array[-2])) - amount)
                    history.append([datetime.now().strftime('%Y-%m-%d'), "withdraw", Decimal128(amount)])
                
                # Update the user's balance in MongoDB
                update_result = login_collection.update_one(
                    {username: {"$exists": True}},
                    {"$set": {username: user_array}}
                )

                if history_array:
                    transaction_history_collection.update_one(
                        {username: {"$exists": True}},
                        {"$set": {username: history}}
                    )
                else:
                    transaction_history_collection.insert_one({username: history})
                
                print(f"Database update result: matched={update_result.matched_count}, modified={update_result.modified_count}")
                print(f"Updated user {username} balance after {transfer_type}")
            else:
                print(f"Transfer status '{transfer_status}' not in successful states")
            client.close()
            return jsonify({
                'success': True,
                'transfer_id': response['transfer']['id'],
                'status': transfer_status
            })
            
        except plaid.ApiException as e:
            print("here 4")
            error_response = json.loads(e.body)
            print(f"Plaid API error: {error_response}")
            client.close()
            return jsonify({
                'error': error_response.get('error_message', 'Transfer failed'),
                'code': error_response.get('error_code'),
                'type': error_response.get('error_type')
            }), 400
            
    except Exception as e:
        print("here 5")
        print(f"Unexpected error: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/store_bank_account', methods=['POST'])
def store_bank_account():
    try:
        data = request.get_json()
        username = data.get('user_id')
        institution_name = data.get('institution_name')
        access_token = data.get('access_token')
        item_id = data.get('item_id')
        
        if not all([username, institution_name, access_token, item_id]):
            return jsonify({'error': 'Missing required fields'}), 400
            
        # Store in MongoDB
        bank_account_collection.insert_one({
            'user_id': username,
            'institution_name': institution_name,
            'access_token': access_token,
            'item_id': item_id,
            'date_linked': datetime.now()
        })
        client.close()
        return jsonify({'success': True}), 200
        
    except Exception as e:
        print(f"Error storing bank account: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/verify-linked-accounts', methods=['POST'])
def verify_linked_accounts():
    data = request.get_json()
    username = data.get('username')
    
    # Query MongoDB for this user's valid accounts
    valid_accounts = []
    user_accounts = bank_account_collection.find({"user_id": username})
    for account in user_accounts:
        valid_accounts.append(account['item_id'])  # or whatever your ID field is
    client.close()
    return jsonify({
        "valid_accounts": valid_accounts
    })

@app.route('/api/remove-linked-accounts', methods=['POST'])
def remove_linked_accounts():
    data = request.get_json()
    access_token = data.get('access_token')
    print(access_token)
    try:
        bank_account_collection.delete_one({"access_token": access_token})
        client.close()
        return jsonify({"message": "Successfully Removed Account"})
    except:
        client.close()
        return jsonify({"message": "No Account To Remove"})


@app.route('/api/data', methods=['POST'])
def server():
    data = request.json
    message = data.get("message", "")
    if "settings" not in message and "loginusername" not in message:
        message = message.lower()
    print("message from server", message)
    if ("loginusername" in message and "1" not in message) and not(("accounttotal" in message)):
        success, account_total, daily_total_array = login(message)
        client.close()
        if success == 1:
            return jsonify({"success": True, "message": "Login successful", "accountTotal": account_total, "daily_total_array": daily_total_array}), 200
        if success == 0:
            return jsonify({"success": False, "message": "Login failed", "accountTotal": account_total, "daily_total_array": daily_total_array}), 401
    if "1ab" in message:
        new_account_success = new_account(message)
        client.close()
        if new_account_success == 0:
            return jsonify({"success": False, "message": "Username already exists"}), 401
        if new_account_success == 1:
            return jsonify({"success": True, "message": "Account created"}), 200
    if "youtube" in message or "instagram" in message or "tiktok" in message:
        labels, values, amount_owned, username, next_buy_price, next_sell_price = stock_graph(message)
        amount_owned = str(math.floor(amount_owned*100) / 100)
        client.close()
        if labels[0] == 0 and values[0] == 0 and float(amount_owned) == 0.0:
            print("here unable to ipo")
            return jsonify({"message": "Unable to IPO. Youtuber either doesn't have enough subscribers or hasn't posted recently enough"})
        login_data = login_collection.find_one({username: {"$exists": True}})
        cash_to_trade = Decimal(str(login_data[username][-2]))
        return jsonify({"labels": labels, "values": values, "cash to trade": cash_to_trade, "amount of stock owned": amount_owned, "next buy price": next_buy_price, "next sell price": next_sell_price})
    if "buy" in message:
        print("here")
        success, new_total, buy_amount, total_stock_owned, new_price, stock_value_dic, stock_date_dic, diverge, next_buy_price, next_sell_price = buy_action(message)
        total_stock_owned = str(math.floor(total_stock_owned*100) / 100)
        print("next buy price", next_buy_price)
        print("next sell price", next_sell_price)
        client.close()
        if success == 2:
            return jsonify({"message": "Pending Order", "account_total": new_total, "buy_total": buy_amount, "total_stock_owned": total_stock_owned,
                            "current_price": new_price, "stock_value_dic": stock_value_dic, "stock_date_dic":stock_date_dic, "next_buy_price":next_buy_price,
                            "next_sell_price": next_sell_price}), 200
        elif success == 1 and diverge == 0:
            return jsonify({"message": "you bought a stock", "account_total": new_total, "buy_total": buy_amount, "total_stock_owned": total_stock_owned,
                            "current_price": new_price, "stock_value_dic": stock_value_dic, "stock_date_dic":stock_date_dic, "next_buy_price":next_buy_price,
                            "next_sell_price": next_sell_price}), 200
        elif success == 1 and diverge == 1:
            return jsonify({"message": "Buy total less than inputted amount because bought more stocks than available on ipo", "account_total": new_total, "buy_total": buy_amount, "total_stock_owned": total_stock_owned,
                            "current_price": new_price, "stock_value_dic": stock_value_dic, "stock_date_dic":stock_date_dic, "next_buy_price":next_buy_price,
                            "next_sell_price": next_sell_price}), 200
        else:
            return jsonify({"message": "Not enough funds", "account_total": new_total, "buy_total": buy_amount, "total_stock_owned": total_stock_owned,
                            "current_price": new_price, "stock_value_dic": stock_value_dic, "stock_date_dic":stock_date_dic, "next_buy_price":next_buy_price,
                            "next_sell_price": next_sell_price}), 200
    if "sell" in message:
        success, new_total, sell_amount, total_stock_owned, new_price, stock_value_dic, stock_date_dic, next_buy_price, next_sell_price = sell_action(message)
        total_stock_owned = str(math.floor(total_stock_owned*100) / 100)
        sell_amount = str(math.floor(sell_amount*100) / 100)
        client.close()
        if success == 2:
            return jsonify({"message": "Pending Order", "account_total": new_total, "sell_total": sell_amount,  "total_stock_owned": total_stock_owned,
                            "current_price": new_price, "stock_value_dic": stock_value_dic, "stock_date_dic":stock_date_dic, "next_buy_price":next_buy_price,
                            "next_sell_price": next_sell_price}), 200
        elif success == 1:
            return jsonify({"message": "you sold a stock(if amount is less than input stock didn't have enough ipo stock left)", "account_total": new_total, "sell_total": sell_amount, "total_stock_owned": total_stock_owned,
                            "current_price": new_price, "stock_value_dic": stock_value_dic, "stock_date_dic":stock_date_dic, "next_buy_price":next_buy_price,
                            "next_sell_price": next_sell_price}), 200
        else:
            return jsonify({"message": "Not enough stock owned", "account_total": new_total, "sell_total": sell_amount, "total_stock_owned": total_stock_owned,
                            "current_price": new_price, "stock_value_dic": stock_value_dic, "stock_date_dic":stock_date_dic, "next_buy_price":next_buy_price,
                            "next_sell_price": next_sell_price}), 200
    if "accounttotal" in message:
        acc_total, account_total_array, agreed, left_to_use = account_total_fetch(message)
        client.close()
        return jsonify({"account_total": acc_total, "account_total_array": account_total_array, "agreed": agreed, "left_to_use": left_to_use})
    if "positions" in message:
        current_value, stocks_owned, quantity, p_account, cost_basis, total_gains, daily_gain, current_stock_value, total_gain_stock, daily_gain_stock = positions_func(message)
        client.close()
        if current_value == 0:
            return jsonify({"message": "No Stocks Owned"})
        else:
            return jsonify({"stocks_owned": stocks_owned, "current_value": current_value, "quantity": quantity, "p_account": p_account, "cost_basis": cost_basis, "total_gains": total_gains, "daily_gain":daily_gain,
                           "current_stock_value": current_stock_value, "total_gain_stock": total_gain_stock, "daily_gain_stock": daily_gain_stock})
    if "orders" in message:
        buy_orders, sell_orders = get_open_orders(message)
        client.close()
        return jsonify({"buy_orders": buy_orders, "sell_orders": sell_orders})
    if "cancel" in message:
        true = cancel_order(message)
        client.close()
        if true == True:
            return jsonify({"message": "Your order was cancelled"})
        else:
            return jsonify({"message": "Unable to cancel your order"})
    if "settings" in message and not "change" in message:
        settings_array = settings_func(message)
        client.close()
        return jsonify({"settings_array":settings_array})
    if "change_settings" in message:
        settings_array = change_settings_func(message)
        client.close()
        return jsonify({"settings_array": settings_array})
    if "top stocks" in message:
        sorted_by_value, sorted_by_time, sorted_by_price, sorted_by_price_low = top_stock()
        client.close()
        return jsonify({"sorted_by_value": sorted_by_value, "sorted_by_time": sorted_by_time, "sorted_by_price": sorted_by_price,
                        "sorted_by_price_low": sorted_by_price_low})
    if "terms" in message or "check" in message:
        acknowledged = terms_ack(message)
        client.close()
        return jsonify({"acknowledged": acknowledged})
    if "history" in message:
        transfer_array, buy_sell_array = transaction_history(message)
        client.close()
        return jsonify({"transfer_array": transfer_array, "buy_sell_array":buy_sell_array})

    
'''
stock_portfolio_collection.update_one({"owner": {"$exists": True}},
    {"$push": {"owner": 'mrbeasts')}},
    upsert=True
)
'''
'''
transaction_history_collection.insert_one({"owner": []})
'''
daily_total_func()
app.run()

#pop from owner array if have zero shouldnt be there anymore if have zero shares in owner.


#done but need to test
#also market order executes at asking price not last executed price change this. so best buy bid for sell or best sell bid for buy.
#this doesn't really work even if only thing is limit order int he book still does ipo price for market orders. fix this. 

#validating financial transactions: https://developer.paypal.com/docs/api/payments.payouts-batch/v1/#payouts_post
#think paything has to be paypal.
#plaid, finicity, stripe and teller.io for bank accounts look into and pick


#need to test new logic where removes buy order if same username as sell order and keeps on iterating through
