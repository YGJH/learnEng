from fastapi import FastAPI, HTTPException
import feedparser
from typing import List, Optional
import datetime

app = FastAPI(title="My No-Key News API", description="A custom RSS-based News API")

# 定義我們的新聞來源 (你可以隨意增加)
RSS_FEEDS = {
    "technology": [
        "https://www.wired.com/feed/rss",
        "http://feeds.bbci.co.uk/news/technology/rss.xml"
    ],
    "business": [
        "http://feeds.bbci.co.uk/news/business/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/Business.xml"
    ],
    "world": [
        "http://feeds.bbci.co.uk/news/world/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/World.xml"
    ],
    "general": [
        "http://feeds.bbci.co.uk/news/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml"
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

@app.get("/")
def read_root():
    return {"message": "Welcome to the Free News API. Use /news to get articles."}

@app.get("/news")
def get_all_news(category: str = "general", limit: int = 10):
    """
    獲取新聞的 Endpoint
    - category: technology, business, world, general
    - limit: 限制回傳篇數
    """
    if category not in RSS_FEEDS:
        raise HTTPException(status_code=404, detail=f"Category '{category}' not found. Available: {list(RSS_FEEDS.keys())}")
    
    # 抓取該分類下所有的 RSS 來源
    urls = RSS_FEEDS[category]
    all_articles = []
    
    for url in urls:
        try:
            articles = parse_feed(url, category)
            all_articles.extend(articles)
        except Exception as e:
            print(f"Error parsing {url}: {e}")
            continue

    # 簡單排序 (如果有發布時間可以做更複雜的排序) 並限制數量
    return {
        "count": len(all_articles[:limit]),
        "category": category,
        "articles": all_articles[:limit]
    }

if __name__ == "__main__":
    # 方便直接用 python news_api.py 執行
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)