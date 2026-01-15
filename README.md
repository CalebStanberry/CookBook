**CookBook iOS App**  

CookBook is an iOS app for managing recipes. It allows users to:  
	•	Sync recipes and collaborate on cookbooks across devices using Cloudflare Workers, KV storage, and R2 for images  
	•	Display recipes without extraneous information or ads  
    •	Add recipes via URL (web scraping & LLM extraction)  
	•	Add recipes manually  
	•	See hero images, favicons, site names, and ingredient substitutions  
	•	Edit recipes, steps, and images  

⸻  

**Screen Shots**  

| | | |
|---|---|---|
| <img src="CookBook Images/IMG_8372.PNG" width="220"> | <img src="CookBook Images/IMG_8376.PNG" width="220"> | <img src="CookBook Images/IMG_8379.PNG" width="220"> |
| <img src="CookBook Images/IMG_8372.PNG" width="220"> | <img src="CookBook Images/IMG_8378.PNG" width="220"> | <img src="..." width="220"> |

⸻  

**Features**  

Recipe Management  
	•	Add a recipe via URL  
	•	Add a recipe manually  
	•	Edit ingredients, steps, and recipe images  
	•	Delete recipes safely  

Recipe Extraction  
	•	Extract recipes from web pages using a Cloudflare Worker that calls an LLM  
	•	Automatically parse ingredients, steps, and substitutions  
	•	Fallback extraction using JSON-LD when LLM fails  

Sync & Sharing  
	•	Recipes are synced across devices using KV storage and R2 for images  
	•	Unique UUIDs prevent collisions between cookbooks  
	•	Automatic version bump on changes  

User Interface  
	•	Two-column card grid for recipes  
	•	Recipe preview includes hero image, favicon, and site name  
	•	Hero images and icons cached locally  
	•	Shimmer effect while images are loading  
	•	Context menus for edit/delete actions  

⸻  

**Architecture**  

iOS App  
	•	SwiftUI front-end  
	•	SwiftData for local storage  
	•	Modular services:  
	•	RecipeExtractionService – LLM & JSON-LD recipe extraction  
	•	CookBookSyncService – sync and sharing logic  
	•	PreviewService – image download and caching  
	•	Components:  
	•	RecipeCardView, RecipeDetailView, IngredientRowView, RecipeHeroThumbnail  

Cloudflare Workers  
	•	Recipe extraction worker  
	•	Receives URL from the app  
	•	Scrapes HTML, cleans it, and sends to LLM (Mistral)  
	•	Returns structured JSON with ingredients, steps, and substitutions  
	•	CookBook Sync worker  
	•	Receives cookbook JSON from app  
	•	Stores in KV and R2 for images  
	•	Simple token-based authentication for bot protection  
