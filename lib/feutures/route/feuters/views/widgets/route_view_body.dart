import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_map_app/core/utils/api_service.dart';
import 'package:google_map_app/core/utils/exceptions.dart';
import 'package:google_map_app/core/utils/places_service.dart';
import 'package:google_map_app/core/utils/location_service.dart';
import 'package:google_map_app/core/utils/routes_service.dart';
import 'package:google_map_app/core/widgets/custom_text_filed.dart';
import 'package:google_map_app/core/widgets/search_list_view.dart';
import 'package:google_map_app/feutures/route/data/models/places_model/places_auto_complete_model.dart';
import 'package:google_map_app/feutures/route/data/models/routes_input_model/destination.dart';
import 'package:google_map_app/feutures/route/data/models/routes_input_model/lat_lng.dart';
import 'package:google_map_app/feutures/route/data/models/routes_input_model/location.dart';
import 'package:google_map_app/feutures/route/data/models/routes_input_model/origin.dart';
import 'package:google_map_app/feutures/route/data/models/routes_input_model/routes_input_model.dart';
import 'package:google_map_app/feutures/route/data/models/routes_model/route.dart';
import 'package:google_map_app/feutures/route/data/models/routes_model/routes_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:uuid/uuid.dart';

class RouteViewBody extends StatefulWidget {
  const RouteViewBody({super.key});

  @override
  State<RouteViewBody> createState() => _RouteViewBodyState();
}

class _RouteViewBodyState extends State<RouteViewBody> {
  late CameraPosition initialCameraPosition;
  late LocationService location;
  late GoogleMapController googleMapController;
  late TextEditingController controller;
  Set<Marker> markers = {};
  late PlacesService placesService;
  List<PlaceModel> places = [];
  late Uuid uuid;
  String? sessionToken;
  late RoutesService routesService;
  late LatLng currentLocation;
  late LatLng currentDistination;

  @override
  void initState() {
    super.initState();
    routesService = RoutesService(apiService: ApiService(dio: Dio()));
    uuid = const Uuid();
    controller = TextEditingController();
    initCameraPosition();
    location = LocationService(location: Location());
    placesService = PlacesService(apiService: ApiService(dio: Dio()));
    fetchPredictions();
  }

  void fetchPredictions() {
    controller.addListener(() async {
      sessionToken ??= uuid.v4();
      print('======================> $sessionToken');
      if (controller.text.isNotEmpty) {
        var results = await placesService.getPredictions(
          input: controller.text,
          sessionToken: sessionToken!,
        );
        places.clear();
        places.addAll(results);
        setState(() {});
      } else {
        places.clear();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    googleMapController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          GoogleMap(
            zoomControlsEnabled: false,
            markers: markers,
            initialCameraPosition: initialCameraPosition,
            onMapCreated: (controller) {
              googleMapController = controller;
              updateCurrentLocation();
            },
          ),
          Positioned(
            top: 16,
            right: 16,
            left: 16,
            child: Column(
              children: [
                SearchTextField(
                  controller: controller,
                ),
                const SizedBox(height: 10),
                SearchListView(
                  places: places,
                  placesService: placesService,
                  onPlaceSelected: (placeDetails) {
                    controller.clear();
                    places.clear();
                    sessionToken = null;
                    currentDistination = LatLng(
                      placeDetails.geometry!.location!.lat!,
                      placeDetails.geometry!.location!.lng!,
                    );
                    setState(() {});
                    getRouteData();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void initCameraPosition() {
    initialCameraPosition = const CameraPosition(
      target: LatLng(29.99552098735423, 31.205921201848618),
      zoom: 1,
    );
  }

  void updateCurrentLocation() async {
    try {
      LocationData locationData = await location.getLocation();
      currentLocation = LatLng(
        locationData.latitude!,
        locationData.longitude!,
      );
      addMarkerToMyLocation(currentLocation);
      await animateCameraToMyLocation(currentLocation);
    } on LocationServiceException catch (e) {
      // TODO
    } on LocationPermissioneException catch (e) {
      // TODO
    } catch (e) {
      // TODO
    }
  }

  void addMarkerToMyLocation(LatLng myLocationPosition) {
    Marker myLocationMarker = Marker(
      markerId: const MarkerId('myLocation'),
      position: myLocationPosition,
      infoWindow: const InfoWindow(title: 'My Location'),
    );
    markers.add(myLocationMarker);
    setState(() {});
  }

  Future<void> animateCameraToMyLocation(LatLng myLocationPosition) async {
    CameraPosition myCameraPosition = CameraPosition(
      target: myLocationPosition,
      zoom: 16,
    );
    await googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(myCameraPosition));
  }

  Future<RouteModel> getRouteData() async {
    Origin origin = Origin(
      location: LocationModel(
        latLng: LatLngModel(
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
        ),
      ),
    );
    Destination distination = Destination(
      location: LocationModel(
        latLng: LatLngModel(
          latitude: currentDistination.latitude,
          longitude: currentDistination.longitude,
        ),
      ),
    );
    RoutesModel routes = await routesService.fetchRoutes(
      routesInputs: RoutesInputModel(
        origin: origin,
        destination: distination,
      ),
    );
    return routes.routes!.first;
  }
}
