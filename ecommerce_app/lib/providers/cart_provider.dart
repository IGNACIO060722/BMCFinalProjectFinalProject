import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }


  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      quantity: json['quantity'],
    );
  }
}


class CartProvider with ChangeNotifier {

  List<CartItem> _items = [];

  String? _userId;
  StreamSubscription? _authSubscription;


  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CartItem> get items => _items;


  double get subtotal {
    double total = 0.0;
    for (var item in _items) {
      total += (item.price * item.quantity);
    }
    return total;
  }

  double get vat {
    return subtotal * 0.12;
  }


  double get totalPriceWithVat {
    return subtotal + vat;
  }


  int get itemCount {

    return _items.fold(0, (total, item) => total + item.quantity);
  }

  CartProvider() {
    print('CartProvider initialized');

    _authSubscription = _auth.authStateChanges().listen((User? user) {
      if (user == null) {

        print('User logged out, clearing cart.');
        _userId = null;
        _items = [];
      } else {

        print('User logged in: ${user.uid}. Fetching cart...');
        _userId = user.uid;
        _fetchCart();
      }
      notifyListeners();
    });
  }


  Future<void> _fetchCart() async {
    if (_userId == null) return;

    try {
      final doc = await _firestore.collection('userCarts').doc(_userId).get();

      if (doc.exists && doc.data()!['cartItems'] != null) {

        final List<dynamic> cartData = doc.data()!['cartItems'];

        _items = cartData.map((item) => CartItem.fromJson(item)).toList();
        print('Cart fetched successfully: ${_items.length} items');
      } else {

        _items = [];
      }
    } catch (e) {
      print('Error fetching cart: $e');
      _items = [];
    }
    notifyListeners();
  }

  // 9. ADD THIS: Saves the current local cart to Firestore
  Future<void> _saveCart() async {
    if (_userId == null) return; // Not logged in, nowhere to save

    try {
      // 1. Convert our List<CartItem> into a List<Map>
      //    (This is why we made toJson()!)
      final List<Map<String, dynamic>> cartData =
      _items.map((item) => item.toJson()).toList();

      // 2. Find the user's document and set the 'cartItems' field
      await _firestore.collection('userCarts').doc(_userId).set({
        'cartItems': cartData,
      });
      print('Cart saved to Firestore');
    } catch (e) {
      print('Error saving cart: $e');
    }
  }

  // 1. THIS IS THE OLD FUNCTION:
  // void addItem(String id, String name, double price) { ... }

  // 2. THIS IS THE NEW, UPDATED FUNCTION:
  void addItem(String id, String name, double price, int quantity) {
    // 3. Check if the item is already in the cart
    var index = _items.indexWhere((item) => item.id == id);

    if (index != -1) {
      // 4. If YES: Add the new quantity to the existing quantity
      _items[index].quantity += quantity;
    } else {
      // 5. If NO: Add the item with the specified quantity
      _items.add(CartItem(
        id: id,
        name: name,
        price: price,
        quantity: quantity, // Use the quantity from the parameter
      ));
    }

    _saveCart(); // This is the same
    notifyListeners(); // This is the same
  }

  // 11. The "Remove Item from Cart" logic
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);

    _saveCart(); // 11. ADD THIS LINE
    notifyListeners(); // Tell widgets to rebuild
  }

  // 1. ADD THIS: Creates an order in the 'orders' collection
  Future<void> placeOrder() async {
    // 2. Check if we have a user and items
    if (_userId == null || _items.isEmpty) {
      // Don't place an order if cart is empty or user is logged out
      throw Exception('Cart is empty or user is not logged in.');
    }

    try {
      // 3. Convert our List<CartItem> to a List<Map> using toJson()
      final List<Map<String, dynamic>> cartData =
      _items.map((item) => item.toJson()).toList();

      // 1. --- THIS IS THE CHANGE ---
      //    Get all our new calculated values
      final double sub = subtotal;
      final double v = vat;
      final double total = totalPriceWithVat;
      final int count = itemCount;

      // 2. Update the data we save to Firestore
      await _firestore.collection('orders').add({
        'userId': _userId,
        'items': cartData,
        'subtotal': sub,       // 3. ADD THIS
        'vat': v,            // 4. ADD THIS
        'totalPrice': total,   // 5. This is now the VAT-inclusive price
        'itemCount': count,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      // --- END OF CHANGE ---

    } catch (e) {
      print('Error placing order: $e');
      // 8. Re-throw the error so the UI can catch it
      throw e;
    }
  }

  // 9. ADD THIS: Clears the cart locally AND in Firestore
  Future<void> clearCart() async {
    // 10. Clear the local list
    _items = [];

    // 11. If logged in, clear the Firestore cart as well
    if (_userId != null) {
      try {
        // 12. Set the 'cartItems' field in their cart doc to an empty list
        await _firestore.collection('userCarts').doc(_userId).set({
          'cartItems': [],
        });
        print('Firestore cart cleared.');
      } catch (e) {
        print('Error clearing Firestore cart: $e');
      }
    }

    // 13. Notify all listeners (this will clear the UI)
    notifyListeners();
  }

  // 12. ADD THIS METHOD (or update it if it exists)
  @override
  void dispose() {
    _authSubscription?.cancel(); // Cancel the auth listener
    super.dispose();
  }
}