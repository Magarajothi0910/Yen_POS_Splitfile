import 'package:flutter/material.dart';

class OpeningCash extends StatelessWidget {
  OpeningCash({super.key});

  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _totalAmountController1 = TextEditingController();
  final TextEditingController _totalAmountController2 = TextEditingController();
  final TextEditingController _totalAmountController3 = TextEditingController();
  final TextEditingController _totalAmountController5 = TextEditingController();
  final TextEditingController _totalAmountController6 = TextEditingController();
  final TextEditingController _totalAmountController7 = TextEditingController();
  final TextEditingController _totalAmountController8 = TextEditingController();
  final TextEditingController _totalAmountController9 = TextEditingController();
  final TextEditingController _totalAmountController4 = TextEditingController();
  final TextEditingController _systemCashController = TextEditingController();
  final TextEditingController _differenceAmountController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    print("opening dinomination open");
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'OPENING CASH DETAILS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DataTable(
                        border: TableBorder.all(color: Colors.blue),
                        columns: const [
                          DataColumn(
                              label: Text(
                            'Denomination',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                            ),
                          )),
                          DataColumn(
                              label: Text(
                            'Numbers',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                            ),
                          )),
                          DataColumn(
                              label: Text(
                            'Total Amount',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                            ),
                          )),
                        ],
                        rows: <DataRow>[
                          DataRow(
                            cells: <DataCell>[
                              const DataCell(Text(
                                '500 *',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              )),
                              DataCell(
                                TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      hintText: 'Total Numbers'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataCell(
                                TextField(
                                  enabled: false,
                                  controller: _totalAmountController,
                                  decoration: const InputDecoration(
                                      hintText: 'Total amount'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          DataRow(
                            cells: <DataCell>[
                              const DataCell(Text(
                                '200 *',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              )),
                              DataCell(
                                TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      hintText: 'Total Numbers'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataCell(
                                TextField(
                                  enabled: false,
                                  controller: _totalAmountController1,
                                  decoration: const InputDecoration(
                                      hintText: 'Total amount'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          DataRow(
                            cells: <DataCell>[
                              const DataCell(Text(
                                '100 *',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              )),
                              DataCell(
                                TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      hintText: 'Total Numbers'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataCell(
                                TextField(
                                  enabled: false,
                                  controller: _totalAmountController2,
                                  decoration: const InputDecoration(
                                      hintText: 'Total amount'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          DataRow(
                            cells: <DataCell>[
                              const DataCell(Text(
                                '50 *',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              )),
                              DataCell(
                                TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      hintText: 'Total Numbers'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataCell(
                                TextField(
                                  enabled: false,
                                  controller: _totalAmountController3,
                                  decoration: const InputDecoration(
                                      hintText: 'Total amount'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          DataRow(
                            cells: <DataCell>[
                              const DataCell(Text(
                                '20 *',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              )),
                              DataCell(
                                TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      hintText: 'Total Numbers'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataCell(
                                TextField(
                                  enabled: false,
                                  controller: _totalAmountController5,
                                  decoration: const InputDecoration(
                                      hintText: 'Total amount'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          DataRow(
                            cells: <DataCell>[
                              const DataCell(Text(
                                '10 *',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              )),
                              DataCell(
                                TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      hintText: 'Total Numbers'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataCell(
                                TextField(
                                  enabled: false,
                                  controller: _totalAmountController6,
                                  decoration: const InputDecoration(
                                      hintText: 'Total amount'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          DataRow(
                            cells: <DataCell>[
                              const DataCell(Text(
                                '5 *',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              )),
                              DataCell(
                                TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      hintText: 'Total Numbers'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataCell(
                                TextField(
                                  enabled: false,
                                  controller: _totalAmountController7,
                                  decoration: const InputDecoration(
                                      hintText: 'Total amount'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          DataRow(
                            cells: <DataCell>[
                              const DataCell(Text(
                                '2 *',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              )),
                              DataCell(
                                TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      hintText: 'Total Numbers'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataCell(
                                TextField(
                                  enabled: false,
                                  controller: _totalAmountController8,
                                  decoration: const InputDecoration(
                                      hintText: 'Total amount'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          DataRow(
                            cells: <DataCell>[
                              const DataCell(Text(
                                '1 *',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                ),
                              )),
                              DataCell(
                                TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      hintText: 'Total Numbers'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              DataCell(
                                TextField(
                                  enabled: false,
                                  controller: _totalAmountController9,
                                  decoration: const InputDecoration(
                                      hintText: 'Total amount'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(children: [
                  const SizedBox(
                    width: 300,
                    child: Text(
                      "Total Manual Amount : ",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: SizedBox(
                      width: 120,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        controller: _totalAmountController4,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          hintText: 'Total is',
                        ),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                        ),
                        enabled: false,
                      ),
                    ),
                  ),
                ]),
                Row(children: [
                  const SizedBox(
                    width: 300,
                    child: Text(
                      "System Cash : ",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: SizedBox(
                      width: 120,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        enabled: false,
                        controller: _systemCashController,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ]),
                Row(children: [
                  const SizedBox(
                    width: 300,
                    child: Text(
                      "Difference Amount  : ",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: SizedBox(
                      width: 120,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        enabled: false,
                        controller: _differenceAmountController,
                        decoration: InputDecoration(
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ]),
                Row(children: [
                  const SizedBox(width: 50),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: SizedBox(
                      width: 100,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                        ),
                        onPressed: () {
                          // Submit button functionality
                        },
                        child: const Text(
                          'Submit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
