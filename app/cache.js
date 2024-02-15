const version = 'v13';

const netFirstResources = [
    "/pow",
    "/pow/",
    "/pow/index.html",
    "/pow/pow.js",
    "/pow/manifest.json",
    "/pow/apple-touch-icon.png"
];

const addResourcesToCache = async (resources) => {
  const cache = await caches.open(version);
  await cache.addAll(resources);
};

const putInCache = async (request, response) => {
  const cache = await caches.open(version);
  await cache.put(request, response);
};


const networkFirst = async ({ request, fallbackUrl }) => {
    console.log('network first for ' + request.url)
    try {
        const responseFromNetwork = await fetch(request);
        putInCache(request, responseFromNetwork.clone());
        return responseFromNetwork;
    } catch (error) {
        const responseFromCache = await caches.match(request);
        if (responseFromCache) {
            return responseFromCache;
        }

        const fallbackResponse = await caches.match(fallbackUrl);
        if (fallbackResponse) {
            return fallbackResponse;
        }

        return new Response('Network error happened', {
            status: 408,
            headers: { 'Content-Type': 'text/plain' },
        });
    }
};


//const cacheFirst = async ({ request, preloadResponsePromise, fallbackUrl }) => {
const cacheFirst = async ({ request, fallbackUrl }) => {
  // First try to get the resource from the cache
  const responseFromCache = await caches.match(request);
  if (responseFromCache) {
    return responseFromCache;
  }

  // Next try to use the preloaded response, if it's there
//  const preloadResponse = await preloadResponsePromise;
//  if (preloadResponse) {
//    console.info('using preload response', preloadResponse);
//    putInCache(request, preloadResponse.clone());
//    return preloadResponse;
//  }

  // Next try to get the resource from the network
  try {
    const responseFromNetwork = await fetch(request);
    // response may be used only once
    // we need to save clone to put one copy in cache
    // and serve second one
    putInCache(request, responseFromNetwork.clone());
    return responseFromNetwork;
  } catch (error) {
    const fallbackResponse = await caches.match(fallbackUrl);
    if (fallbackResponse) {
      return fallbackResponse;
    }
    // when even the fallback response is not available,
    // there is nothing we can do, but we must always
    // return a Response object
    return new Response('Network error happened', {
      status: 408,
      headers: { 'Content-Type': 'text/plain' },
    });
  }
};

//const enableNavigationPreload = async () => {
//  if (self.registration.navigationPreload) {
//    // Enable navigation preloads!
//    await self.registration.navigationPreload.enable();
//  }
//};


const deleteCache = async (key) => {
    await caches.delete(key);
};

const deleteOldCaches = async () => {
    const cacheKeepList = [version];
    const keyList = await caches.keys();
    const cachesToDelete = keyList.filter((key) => !cacheKeepList.includes(key));
    await Promise.all(cachesToDelete.map(deleteCache));
};


self.addEventListener('activate', (event) => {
    event.waitUntil(deleteOldCaches());
//    event.waitUntil(enableNavigationPreload());
});

self.addEventListener('install', (event) => {
  event.waitUntil(
    addResourcesToCache([
      "/pow",
      "/pow/",
      "/pow/index.html",
      "/pow/pow.js",
      "/pow/manifest.json",
      "/pow/apple-touch-icon.png",

      "/pow/nsw25k.js",
      "/pow/maps/NSW_25k_Coast_South_10_4.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_13.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_16.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_8.jpg",
      "/pow/maps/NSW_25k_Coast_South_16_11.jpg",
      "/pow/maps/NSW_25k_Coast_South_10_5.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_14.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_5.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_9.jpg",
      "/pow/maps/NSW_25k_Coast_South_16_4.jpg",
      "/pow/maps/NSW_25k_Coast_South_10_6.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_15.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_6.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_10.jpg",
      "/pow/maps/NSW_25k_Coast_South_16_5.jpg",
      "/pow/maps/NSW_25k_Coast_South_11_10.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_16.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_7.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_11.jpg",
      "/pow/maps/NSW_25k_Coast_South_16_6.jpg",
      "/pow/maps/NSW_25k_Coast_South_11_11.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_4.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_8.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_12.jpg",
      "/pow/maps/NSW_25k_Coast_South_16_7.jpg",
      "/pow/maps/NSW_25k_Coast_South_11_12.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_5.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_9.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_13.jpg",
      "/pow/maps/NSW_25k_Coast_South_16_8.jpg",
      "/pow/maps/NSW_25k_Coast_South_11_13.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_6.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_10.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_14.jpg",
      "/pow/maps/NSW_25k_Coast_South_16_9.jpg",
      "/pow/maps/NSW_25k_Coast_South_11_14.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_7.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_11.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_15.jpg",
      "/pow/maps/NSW_25k_Coast_South_17_4.jpg",
      "/pow/maps/NSW_25k_Coast_South_11_4.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_8.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_12.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_16.jpg",
      "/pow/maps/NSW_25k_Coast_South_17_5.jpg",
      "/pow/maps/NSW_25k_Coast_South_11_5.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_9.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_13.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_4.jpg",
      "/pow/maps/NSW_25k_Coast_South_17_6.jpg",
      "/pow/maps/NSW_25k_Coast_South_11_6.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_10.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_14.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_5.jpg",
      "/pow/maps/NSW_25k_Coast_South_17_7.jpg",
      "/pow/maps/NSW_25k_Coast_South_11_8.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_11.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_15.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_6.jpg",
      "/pow/maps/NSW_25k_Coast_South_17_8.jpg",
      "/pow/maps/NSW_25k_Coast_South_11_9.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_12.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_16.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_7.jpg",
      "/pow/maps/NSW_25k_Coast_South_18_5.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_10.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_13.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_5.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_8.jpg",
      "/pow/maps/NSW_25k_Coast_South_18_6.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_11.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_14.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_6.jpg",
      "/pow/maps/NSW_25k_Coast_South_15_9.jpg",
      "/pow/maps/NSW_25k_Coast_South_18_7.jpg",
      "/pow/maps/NSW_25k_Coast_South_12_12.jpg",
      "/pow/maps/NSW_25k_Coast_South_13_15.jpg",
      "/pow/maps/NSW_25k_Coast_South_14_7.jpg",
      "/pow/maps/NSW_25k_Coast_South_16_10.jpg",
      "/pow/maps/NSW_25k_Coast_South_18_8.jpg",
      "/pow/maps/NSW_25k_Coast_South_16_12.jpg",
      "/pow/maps/NSW_25k_Coast_South_16_13.jpg",
      "/pow/maps/NSW_25k_Coast_South_16_14.jpg",
      "/pow/maps/NSW_25k_Coast_South_11_15.jpg",
      "/pow/maps/NSW_25k_Coast_South_19_8.jpg",
      "/pow/maps/NSW_25k_Coast_South_17_9.jpg",
      "/pow/maps/NSW_25k_Coast_South_18_9.jpg",
      "/pow/maps/NSW_25k_Coast_South_19_9.jpg",
      "/pow/maps/NSW_25k_Coast_South_17_10.jpg",
      "/pow/maps/NSW_25k_Coast_South_18_10.jpg",
      "/pow/maps/NSW_25k_Coast_South_19_10.jpg",
      "/pow/maps/NSW_25k_Coast_South_17_11.jpg",
      "/pow/maps/NSW_25k_Coast_South_18_11.jpg",
      "/pow/maps/NSW_25k_Coast_South_19_11.jpg",
      "/pow/maps/NSW_25k_Coast_South_22_12.jpg",
      "/pow/maps/NSW_25k_Coast_South_22_13.jpg",
      "/pow/maps/NSW_25k_Coast_South_22_14.jpg",
      "/pow/maps/NSW_25k_Coast_South_23_12.jpg",
      "/pow/maps/NSW_25k_Coast_South_23_13.jpg",
      "/pow/maps/NSW_25k_Coast_South_23_14.jpg",
      "/pow/maps/NSW_25k_Coast_South_24_12.jpg",
      "/pow/maps/NSW_25k_Coast_South_24_13.jpg",
      "/pow/maps/NSW_25k_Coast_South_24_14.jpg",
      "/pow/maps/blank.jpg"
    ])
  );
});

self.addEventListener('fetch', (event) => {

//console.log(event.request);

    if (netFirstResources.includes(event.request.url.split(/hudmol.com/)[1])) {
        event.respondWith(
            networkFirst({
                request: event.request,
                fallbackUrl: '/pow',
            }))
    } else {
        event.respondWith(
            cacheFirst({
                request: event.request,
                //      preloadResponsePromise: event.preloadResponse,
                fallbackUrl: '/pow',
            }))
    }
});
