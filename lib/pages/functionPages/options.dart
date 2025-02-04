// ignore_for_file: camel_case_types

import 'package:flutter/material.dart';
import 'package:sdihc/pages/Tabs/add_seles_tab.dart';
import 'package:sdihc/pages/functionPages/billScreen.dart';
import 'package:sdihc/pages/functionPages/submit_bill_screen.dart';

class newAddPage extends StatefulWidget {
  const newAddPage({super.key});

  @override
  State<newAddPage> createState() => _newAddPageState();
}

class GridItem {
  final String imagePath;
  final String title;
  final Widget screen;
  final Color color;

  GridItem({
    required this.imagePath,
    required this.title,
    required this.screen,
    required this.color,
  });
}

class _newAddPageState extends State<newAddPage> {
  final List<GridItem> _gridItems = [
    GridItem(
      imagePath: 'assets/images/billlist.jpg',
      title: 'Bill List',
      screen: const BillsScreen(),
      color: Colors.pink.shade300,
    ),
    GridItem(
      imagePath: 'assets/images/bill1.jpg',
      title: 'Submit bill',
      screen: const SubmitBillScreen(),
      color: Colors.green.shade300,
    ),
    GridItem(
      imagePath: 'assets/images/chart2.jpg',
      title: 'Spending Chart',
      screen: const AddSalesTab(),
      color: Colors.purple.shade300,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Icon(Icons.menu),
        title: Text('Data'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              width: 36,
              height: 30,
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: Text("0"),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Container(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                /*Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(
                          image: AssetImage('assets/images/head1light.jpg'),
                          fit: BoxFit.cover)),
                  child: Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                            begin: Alignment.bottomRight,
                            colors: [
                              Colors.black.withOpacity(.4),
                              Colors.black.withOpacity(.1)
                            ])),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Database',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 35,
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(
                          height: 20,
                        )
                      ],
                    ),
                  ),
                ),*/
                SizedBox(
                  height: 20,
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: _gridItems
                        .map((item) => Card(
                              color: Colors.transparent,
                              elevation: 0,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => item.screen),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: item.color,
                                    /*image: DecorationImage(
                                      image: AssetImage(item.imagePath),
                                      fit: BoxFit.cover,
                                    ),*/
                                  ),
                                  child: Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          /*shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 6,
                                              offset: Offset(2, 2),
                                            )
                                          ],*/
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
