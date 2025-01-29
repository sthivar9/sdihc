import 'package:flutter/material.dart';

class Addpage extends StatefulWidget {
  const Addpage({super.key});

  @override
  State<Addpage> createState() => _AddpageState();
}

class _AddpageState extends State<Addpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    image: DecorationImage(
                      image: AssetImage('assets/images/image.png'),
                      fit: BoxFit.cover,
                    ),
                  ), // Placeholder for image
                ),
                Positioned(
                  top: 40,
                  left: 16,
                  child: Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("Subjects",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("Recommendations for you",
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                          child: Text("Mathematics",
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16))),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                          child: Text("Geography",
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16))),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("Your Schedule",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("Next lessons",
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                    child: Text("Biology\nChapter 3: Animal Kingdom",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
