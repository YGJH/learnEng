from fastapi import FastAPI, HTTPException
import feedparser
from typing import List, Optional
import datetime
import json
import os
from pathlib import Path

app = FastAPI(title="My No-Key News API", description="A custom RSS-based News API")

# 定義 JSON 文件路徑
NEWS_JSON_FILE = Path(__file__).parent / "news.json"

# 定義我們的新聞來源 (你可以隨意增加)
RSS_FEEDS = {
    "technology": [
        "https://www.wired.com/feed/rss",
        "http://feeds.bbci.co.uk/news/technology/rss.xml",
        "https://techcrunch.com/feed/",
        "https://www.theverge.com/rss/index.xml"
    ],
    "business": [
        "http://feeds.bbci.co.uk/news/business/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/Business.xml",
        "https://www.cnbc.com/id/10000664/device/rss/rss.html",
        "https://feeds.a.dj.com/rss/WSJcomUSBusiness.xml"
    ],
    "world": [
        "http://feeds.bbci.co.uk/news/world/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/World.xml",
        "https://www.aljazeera.com/xml/rss/all.xml",
        "http://rss.cnn.com/rss/edition_world.rss"
    ],
    "science": [
        "https://www.sciencedaily.com/rss/top_news.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/Science.xml",
        "https://www.newscientist.com/feed/home"
    ],
    "health": [
        "http://feeds.bbci.co.uk/news/health/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/Health.xml",
        "https://www.medicalnewstoday.com/feed"
    ],
    "sports": [
        "http://feeds.bbci.co.uk/sport/rss.xml",
        "https://www.espn.com/espn/rss/news",
        "https://rss.nytimes.com/services/xml/rss/nyt/Sports.xml"
    ],
    "entertainment": [
        "https://www.variety.com/feed/",
        "https://rss.nytimes.com/services/xml/rss/nyt/Movies.xml",
        "https://www.hollywoodreporter.com/feed/"
    ],
    "general": [
        "http://feeds.bbci.co.uk/news/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml",
        "http://rss.cnn.com/rss/edition.rss"
    ]
}

def parse_feed(url: str, category: str):
    """解析單個 RSS URL 並標準化格式"""
    news_items = []
    feed = feedparser.parse(url)
    
    for entry in feed.entries:
        # 嘗試獲取發布時間，如果沒有則使用當前時間
        pub_date = getattr(entry, 'published', str(datetime.datetime.now()))
        
        item = {
            "title": entry.title,
            "link": entry.link,
            "summary": getattr(entry, 'summary', 'No summary available'),
            "source": feed.feed.get('title', 'Unknown Source'),
            "published_at": pub_date,
            "category": category
        }
        news_items.append(item)
    return news_items

def save_news_to_json(news_data: dict):
    """將新聞數據保存到 JSON 文件"""
    try:
        # 添加時間戳
        news_data["fetched_at"] = datetime.datetime.now().isoformat()
        
        with open(NEWS_JSON_FILE, 'w', encoding='utf-8') as f:
            json.dump(news_data, f, ensure_ascii=False, indent=2)
        
        print(f"✅ News saved to {NEWS_JSON_FILE}")
        print(f"📊 Total articles: {news_data['count']}")
    except Exception as e:
        print(f"❌ Error saving news to JSON: {e}")

def load_news_from_json():
    """從 JSON 文件加載新聞數據"""
    if NEWS_JSON_FILE.exists():
        try:
            with open(NEWS_JSON_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
            print(f"📰 Loaded {data.get('count', 0)} articles from cache")
            return data
        except Exception as e:
            print(f"⚠️ Error loading news from JSON: {e}")
            return None
    return None

@app.get("/")
def read_root():
    return {
        "message": "Welcome to the Free News API. Use /news to get articles.",
        "cache_file": str(NEWS_JSON_FILE),
        "cache_exists": NEWS_JSON_FILE.exists()
    }

@app.get("/news/cached")
def get_cached_news():
    """
    從本地 JSON 文件讀取緩存的新聞
    """
    cached_data = load_news_from_json()
    if cached_data:
        return cached_data
    else:
        raise HTTPException(
            status_code=404,
            detail="No cached news found. Please call /news to fetch fresh data."
        )

#@app.get("/news")
def get_all_news(category: Optional[str] = None, limit: int = 100, use_cache: bool = False):
    """
    獲取新聞的 Endpoint
    - category: technology, business, world, general (如果不指定則抓取所有類別)
    - limit: 限制回傳篇數 (預設 50 篇)
    - use_cache: 是否使用緩存（預設 False，會重新抓取）
    """
    # 如果使用緩存且緩存存在
    if use_cache:
        cached_data = load_news_from_json()
        if cached_data:
            # 根據請求的 category 和 limit 過濾緩存數據
            if category and category != "all" and cached_data.get("category") == "all":
                filtered_articles = [
                    a for a in cached_data.get("articles", [])
                    if a.get("category") == category
                ][:limit]
                return {
                    "count": len(filtered_articles),
                    "category": category,
                    "articles": filtered_articles,
                    "from_cache": True
                }
            return {**cached_data, "from_cache": True}
    
    all_articles = []
    
    # 如果沒有指定 category，就抓取所有類別
    if category is None or category == "all":
        categories_to_fetch = RSS_FEEDS.keys()
        mixed_category = "all"
    else:
        if category not in RSS_FEEDS:
            raise HTTPException(
                status_code=404, 
                detail=f"Category '{category}' not found. Available: {list(RSS_FEEDS.keys())}"
            )
        categories_to_fetch = [category]
        mixed_category = category
    
    # 抓取所有指定類別的 RSS 來源
    for cat in categories_to_fetch:
        urls = RSS_FEEDS[cat]
        for url in urls:
            try:
                articles = parse_feed(url, cat)
                all_articles.extend(articles)
            except Exception as e:
                print(f"Error parsing {url}: {e}")
                continue

    # 根據發布時間排序（最新的在前面）
    try:
        all_articles.sort(
            key=lambda x: datetime.datetime.strptime(
                x['published_at'], 
                "%a, %d %b %Y %H:%M:%S %z"
            ) if x['published_at'] else datetime.datetime.min,
            reverse=True
        )
    except Exception as e:
        print(f"Sorting error: {e}")
        # 如果排序失敗，就保持原順序
        pass

    # 限制數量
    limited_articles = all_articles[:limit]
    
    # 準備返回的數據
    response_data = {
        "count": len(limited_articles),
        "category": mixed_category,
        "articles": limited_articles
    }
    
    # 保存到 JSON 文件
    save_news_to_json(response_data)
    
    return response_data

if __name__ == "__main__":
    # 方便直接用 python news_api.py 執行
  #  import uvicorn
    get_all_news()
 #   uvicorn.run(app, host="0.0.0.0", port=9902)
