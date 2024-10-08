import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPremiumContent(context),
    );
  }

  Widget _buildPremiumContent(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Ortalamak için değiştirildi
          children: [
            // Üst orta konumda çarpı butonu
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  const Text(
                    "Vertex Premium Satın Al",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Vertex AI'ın tüm özelliklerine tam erişim sağlayarak\n"
                        'yapay zeka deneyimini doruklarına kadar yaşayın!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[400],
                    ),
                  ),
                  SizedBox(height: 30),
                  Image.asset(
                    'assets/vertexailogo.png',
                    height: 100,
                  ),
                  SizedBox(height: 30),
                  _buildSubscriptionOption(
                    title: 'Yıllık',
                    description: 'İlk 30 gün ücretsiz - Sonra ₺200/Yıl',
                    isBestValue: true,
                  ),
                  SizedBox(height: 15),
                  _buildSubscriptionOption(
                    title: 'Aylık',
                    description: 'İlk 7 gün ücretsiz - Sonra ₺20/Ay',
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Color(0xFF141414),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      padding: EdgeInsets.symmetric(
                          vertical: 16, horizontal: 60),
                    ),
                    child: Text(
                      '7 günlük ücretsiz deneme başlat',
                      style: TextStyle(
                        fontSize: 16.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Bu siparişi vererek, Hizmet Şartları ve Gizlilik Politikasını kabul edersiniz. '
                          'Abonelik, mevcut dönem bitmeden en az 24 saat önce otomatik yenileme kapatılmadıkça '
                          'otomatik olarak yenilenir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOption({
    required String title,
    required String description,
    bool isBestValue = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isBestValue)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding:
                  EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text(
                    'En İyi Fiyat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
