import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kotproviders/employee_provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

Widget buildWaiterDropdown(BuildContext context) {
  return Consumer<EmployeeProvider>(
    builder: (context, employeeProvider, _) {
      // Ensure the employee data is loaded
      if (employeeProvider.employees.isEmpty) {
        employeeProvider.fetchAndStoreEmployees();
      }

      // Map employees to a list of dropdown items
      final List<DropdownMenuItem<String>> dropdownItems =
          employeeProvider.employees.map((employee) {
        String fullName = "${employee.firstName} ${employee.lastName ?? ''}";
        return DropdownMenuItem<String>(
          value: fullName,
          child: Text(fullName),
        );
      }).toList();

      TextEditingController searchController = TextEditingController();

      return DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          value: (employeeProvider.selectedWaiter != null &&
                  employeeProvider.selectedWaiter!.isNotEmpty)
              ? employeeProvider.selectedWaiter
              : null,
          onChanged: (String? value) {
            if (value != null) {
              employeeProvider.setSelectedWaiter(value); // Persist in provider
            }
          },
          items: dropdownItems,
          dropdownStyleData: DropdownStyleData(
            maxHeight: 300,
            width: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            offset: const Offset(0, 0),
            scrollbarTheme: ScrollbarThemeData(
              radius: const Radius.circular(40),
              thickness: MaterialStateProperty.all<double>(6),
              thumbVisibility: MaterialStateProperty.all<bool>(true),
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(
            height: 40,
            padding: EdgeInsets.only(left: 14, right: 14),
          ),
          dropdownSearchData: DropdownSearchData(
            searchController: searchController,
            searchInnerWidgetHeight: 60,
            searchInnerWidget: Padding(
              padding: const EdgeInsets.all(8),
              child: TextFormField(
                controller: searchController,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  hintText: 'Search employees...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            searchMatchFn: (item, searchValue) {
              return item.value!
                  .toLowerCase()
                  .contains(searchValue.toLowerCase());
            },
          ),
          hint: const Text(
            'Select your name',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black12, // Border color
            ),
          ),
          buttonStyleData: ButtonStyleData(
            height: 50,
            width: 300,
            padding: EdgeInsets.only(left: 14, right: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.black12, // Border color
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8.0), // Rounded border
              color: Colors.white, // Dropdown background color
            ),
          ),
          iconStyleData: const IconStyleData(
            icon: Icon(
              Icons.arrow_drop_down,
              color: Colors.grey,
            ),
            iconSize: 24,
          ),
        ),
      );
    },
  );
}
