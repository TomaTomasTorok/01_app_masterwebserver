// Future<void> _externalDevice(List<List<int>> data) async {
//   for (List<int> item in data) {
//     print(item);
//   }
//   try {
//     final url = 'http://${widget.workplace.ipAddress}/data';
//     //  const url = 'http://192.168.0.184/data';
//     final response = await http.post(
//       Uri.parse(url),
//       headers: {"Content-Type": "application/json"},
//       body: json.encode({"data": data}),
//     );
//
//     if (response.statusCode == 200) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request successful!")));
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request failed: ${response.statusCode}")));
//     }
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to connect to the device: $e")));
//   }
// }
