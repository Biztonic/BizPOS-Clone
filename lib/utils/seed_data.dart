
class SeedItem {
  final String name;
  final String category;
  final String storeType;
  final double price;
  final String image;

  const SeedItem({
    required this.name,
    required this.category,
    required this.storeType,
    required this.price,
    required this.image,
  });
}

const List<SeedItem> seedData = [
  // --- RESTAURANT (10 items) ---
  SeedItem(
    name: "Classic Cheeseburger",
    category: "Burgers",
    storeType: "Restaurant",
    price: 150.0,
    image: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Pepperoni Pizza",
    category: "Pizza",
    storeType: "Restaurant",
    price: 350.0,
    image: "https://images.unsplash.com/photo-1628840042765-356cda07504e?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Caesar Salad",
    category: "Salads",
    storeType: "Restaurant",
    price: 220.0,
    image: "https://images.unsplash.com/photo-1550304943-4f24f54ddde9?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Grilled Salmon",
    category: "Seafood",
    storeType: "Restaurant",
    price: 550.0,
    image: "https://images.unsplash.com/photo-1485921325833-c51d91cd65b2?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Iced Cappuccino",
    category: "Beverages",
    storeType: "Restaurant",
    price: 120.0,
    image: "https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Chocolate Lava Cake",
    category: "Desserts",
    storeType: "Restaurant",
    price: 180.0,
    image: "https://images.unsplash.com/photo-1606313564200-e75d5e30476d?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Spaghetti Carbonara",
    category: "Pasta",
    storeType: "Restaurant",
    price: 280.0,
    image: "https://images.unsplash.com/photo-1612874742237-982867143824?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Fresh Orange Juice",
    category: "Beverages",
    storeType: "Restaurant",
    price: 90.0,
    image: "https://images.unsplash.com/photo-1613478223719-2ab802602423?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Crispy French Fries",
    category: "Sides",
    storeType: "Restaurant",
    price: 80.0,
    image: "https://images.unsplash.com/photo-1630384060421-cb20d0e0649e?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Mushroom Risotto",
    category: "Main Course",
    storeType: "Restaurant",
    price: 320.0,
    image: "https://images.unsplash.com/photo-1476124369491-e7addf5db371?auto=format&fit=crop&w=500&q=60",
  ),

  // --- GROCERY (10 items) ---
  SeedItem(
    name: "Organic Bananas (1kg)",
    category: "Produce",
    storeType: "Grocery",
    price: 60.0,
    image: "https://images.unsplash.com/photo-1603833665858-e61d17a86224?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Whole Wheat Bread",
    category: "Bakery",
    storeType: "Grocery",
    price: 45.0,
    image: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Fresh Milk (1L)",
    category: "Dairy",
    storeType: "Grocery",
    price: 70.0,
    image: "https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Farm Eggs (12 pack)",
    category: "Dairy",
    storeType: "Grocery",
    price: 120.0,
    image: "https://images.unsplash.com/photo-1518563222391-166c2f3544fc?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Basmati Rice (5kg)",
    category: "Grains",
    storeType: "Grocery",
    price: 650.0,
    image: "https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Olive Oil (500ml)",
    category: "Pantry",
    storeType: "Grocery",
    price: 450.0,
    image: "https://images.unsplash.com/photo-1474979266404-7cadd2592500?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Red Apples (1kg)",
    category: "Produce",
    storeType: "Grocery",
    price: 180.0,
    image: "https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Potato Chips (Salted)",
    category: "Snacks",
    storeType: "Grocery",
    price: 30.0,
    image: "https://images.unsplash.com/photo-1566478988047-8c8b9a1fd5f6?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Dark Chocolate Bar",
    category: "Snacks",
    storeType: "Grocery",
    price: 150.0,
    image: "https://images.unsplash.com/photo-1511381939415-e44015466834?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Almonds (200g)",
    category: "Dry Fruits",
    storeType: "Grocery",
    price: 280.0,
    image: "https://images.unsplash.com/photo-1606914502577-74220c4c4415?auto=format&fit=crop&w=500&q=60",
  ),

  // --- FASHION (10 items) ---
  SeedItem(
    name: "Cotton Crew T-Shirt",
    category: "Men's Wear",
    storeType: "Fashion",
    price: 495.0,
    image: "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Classic Blue Jeans",
    category: "Denim",
    storeType: "Fashion",
    price: 1295.0,
    image: "https://images.unsplash.com/photo-1542272454315-4c01d7abdf4a?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Summer Floral Dress",
    category: "Women's Wear",
    storeType: "Fashion",
    price: 1450.0,
    image: "https://images.unsplash.com/photo-1515372039744-b8f02a3ae446?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Leather Jacket",
    category: "Outerwear",
    storeType: "Fashion",
    price: 3500.0,
    image: "https://images.unsplash.com/photo-1551028919-6016b7c40d99?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Running Sneakers",
    category: "Footwear",
    storeType: "Fashion",
    price: 2495.0,
    image: "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Canvas Tote Bag",
    category: "Accessories",
    storeType: "Fashion",
    price: 350.0,
    image: "https://images.unsplash.com/photo-1597484661643-2f5fef640dd1?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Silk Scarf",
    category: "Accessories",
    storeType: "Fashion",
    price: 550.0,
    image: "https://images.unsplash.com/photo-1584030373081-f37b7bb4fa8e?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Aviator Sunglasses",
    category: "Accessories",
    storeType: "Fashion",
    price: 895.0,
    image: "https://images.unsplash.com/photo-1572635196237-14b3f281503f?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Formal White Shirt",
    category: "Men's Wear",
    storeType: "Fashion",
    price: 995.0,
    image: "https://images.unsplash.com/photo-1596755094514-f87e34085b2c?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Woolen Beanie",
    category: "Winter Wear",
    storeType: "Fashion",
    price: 350.0,
    image: "https://images.unsplash.com/photo-1576871337632-b9aef4c17ab9?auto=format&fit=crop&w=500&q=60",
  ),

  // --- OTHER / ELECTRONICS (10 items) ---
  SeedItem(
    name: "USB-C Charging Cable",
    category: "Accessories",
    storeType: "Other",
    price: 250.0,
    image: "https://images.unsplash.com/photo-1610457632194-e8cc4bb36ba7?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Wireless Mouse",
    category: "Peripherals",
    storeType: "Other",
    price: 450.0,
    image: "https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Mechanical Keyboard",
    category: "Peripherals",
    storeType: "Other",
    price: 2500.0,
    image: "https://images.unsplash.com/photo-1595225476474-87563907a212?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Bluetooth Headphones",
    category: "Audio",
    storeType: "Other",
    price: 1500.0,
    image: "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Smart Watch Strap",
    category: "Accessories",
    storeType: "Other",
    price: 350.0,
    image: "https://images.unsplash.com/photo-1517502474097-f9b30659dadb?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Phone Case (iPhone 14)",
    category: "Accessories",
    storeType: "Other",
    price: 295.0,
    image: "https://images.unsplash.com/photo-1586942389045-318b329479b6?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Power Bank 10000mAh",
    category: "Power",
    storeType: "Other",
    price: 850.0,
    image: "https://images.unsplash.com/photo-1609592424364-c7da41940742?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "HDMI Cable (2m)",
    category: "Cables",
    storeType: "Other",
    price: 150.0,
    image: "https://images.unsplash.com/photo-1558245846-5d654486d34b?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Webcam 1080p",
    category: "Peripherals",
    storeType: "Other",
    price: 1250.0,
    image: "https://images.unsplash.com/photo-1594636797743-02f5e8b6b23b?auto=format&fit=crop&w=500&q=60",
  ),
  SeedItem(
    name: "Screen Cleaning Kit",
    category: "Cleaning",
    storeType: "Other",
    price: 125.0,
    image: "https://images.unsplash.com/photo-1626296720914-8f0ae5935399?auto=format&fit=crop&w=500&q=60",
  ),
];
