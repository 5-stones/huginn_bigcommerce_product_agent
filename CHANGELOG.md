# [2.1.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v2.0.0...v2.1.0) (2021-05-25)


### Bug Fixes

* **error handling:** Fix Faraday response processing ([7add633](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/7add6338920394f38500b8e1cb2984374d9a55ba))


### Features

* **BigCommerceProductError:** Streamline error handling/logging ([109687c](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/109687cf44fac13bd98de6974dad4d265183dce3))



# [2.0.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.12.0...v2.0.0) (2021-03-24)


### Bug Fixes

* **big_commerce_product_agent:** fix handling of error events ([a819372](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/a819372500ab66ed1a83ddbcb879e326173a58db))
* **big_commerce_product_agent:** Improve agent execution speed ([59cd4f3](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/59cd4f3f5a1052926680605b1c754dd6064f7c2f))
* **bigcommerce_product_agent:** Change handling of product availability ([7010113](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/7010113e0ff14f1cc466f1c7cd8b34f7002d6b0d))
* **bigcommerce_product_agent:** fix syntax error ([ab34948](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/ab349483361a60667da3ed6fc4e2486075c65bdd))
* **bigcommerce_product_agent:** improve error handling for upserts ([ec1bf58](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/ec1bf58940a8585941ff3d1fcfd13b9e87a975f3))
* **client/product,bigcommerce_product_agent:** Consolidate API requests ([070669a](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/070669a1b3a4d622b833255ef0469724f2f551bf))
* **product_mapper:** add isbn to search terms ([9a8dc73](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/9a8dc73ae0e9a49726bccebf981328c16492898f))
* **product_mapper:** Adjust handling of product availability ([56dae39](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/56dae3904feb1365272d9558467a293260a0f560))
* **product_mapper:** set retail_price ([c486e40](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/c486e40ab7cca75a26fff9ba364f991b4cfa083f))
* **product_mapper.rb:** fix keywords ([4760dd5](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/4760dd5835bd654c22fbac4f8a37cc23ae2f4214))


### Features

* **big_commerce_product_agent:** delete inactive products ([e8f3f75](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/e8f3f7585a26239e73f902682fc1cdd81b008c28))
* **big_commerce_product_agent:** Support conditional inventory tracking ([5317669](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/53176699859ccbed49605e97bb3199b2dd4cf67d))
* **product_mapper:** track inventory ([5d3083f](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/5d3083f8dcbd07396ae5485cc5ca618b8bb04821))
* **product_mapper:** update inventory tracking for physical products ([a0fe2bb](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/a0fe2bbc35a987ea4537ceb048bbf940306ffdef))



# [1.12.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.11.1...v1.12.0) (2020-11-06)


### Features

* **bigcommerce_product_agent,product_mapper:** Allow product deletion ([51b65ae](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/51b65aefb6822549c3ebb1011f1fc26e9f0a662e))



## [1.11.1](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.11.0...v1.11.1) (2020-11-03)


### Bug Fixes

* **product_mapper:** get categories after splitting into dig and phy ([d252e2d](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/d252e2dfae2d4e8b36e9d757a7e440bc3555cb39))



# [1.11.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.10.1...v1.11.0) (2020-09-03)


### Features

* **variant_mapper:** update msrp on variants ([0ed8245](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/0ed8245d544176ebcc59ac985994ee1e8d99c337))



## [1.10.1](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.10.0...v1.10.1) (2020-07-21)


### Bug Fixes

* **bigcommerce_product_agent:** only try to delete something if exists ([7327234](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/7327234b5e330790efc89096b8e46884705e5530))



# [1.10.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.9.0...v1.10.0) (2020-07-16)


### Features

* **meta_field.rb, product_option.rb:** log errors in delete meta-field and create product-option ([15f8bcf](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/15f8bcf73cee2ccec60086adab53470869388d98))



# [1.9.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.8.0...v1.9.0) (2020-07-15)


### Bug Fixes

* **bigcommerce_product_agent.rb, product_mapper.rb:** define a page title with no disambiguation tag ([57c663e](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/57c663e191abebf40286499b3ae652644367fccb))


### Features

* **variant.rb:** log payload of errors in variants ([0b4fe27](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/0b4fe277cd1d7a649e0d59d6d80941d4c90ba5a6))



# [1.8.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.7.0...v1.8.0) (2020-07-14)


### Features

* **client/product.rb:** improve error logging for bad server responses ([9a0c671](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/9a0c6718d55e729b2446bc7be211165c77bc7f97))



# [1.7.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.6.0...v1.7.0) (2020-07-07)


### Features

* **huginn_bigcommerce_product_agent.rb:** disambiguate products by listing product types in name ([e063565](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/e063565983cfd7827b8db5db34e333359ea6afea))



# [1.6.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.5.0...v1.6.0) (2020-06-19)


### Features

* **product_mapper:** update availability on products ([a120daf](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/a120daf550a96e048a0f5f796ab6e66df28b8767))



# [1.5.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.4.3...v1.5.0) (2020-06-12)


### Features

* **bigcommerce_product_agent.rb, product_mapper.rb:** add product skus to search terms ([9d6f6a8](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/9d6f6a8729d9e33d2de52580675a1a96fe55ffac))



## [1.4.3](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.4.2...v1.4.3) (2020-06-05)



## [1.4.2](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.4.1...v1.4.2) (2020-06-05)


### Features

* **variant_mapper, bigcommerce_product_agent:** list of not purchasable ([27c37e0](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/27c37e08583e064a92ab10031fe7753f0e7170ff))



## [1.4.1](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.4.0...v1.4.1) (2020-05-26)


### Bug Fixes

* **lib/huginn_bigcommerce_product_agent:** make sure meta_fields are being passed into new event ([8de65e7](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/8de65e7cf31afb542674cd38486eea6762216438))



# [1.4.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.3.5...v1.4.0) (2020-05-13)


### Features

* **product, bigcommerce_product_agent, product_mapper:** wrapper sku ([da74850](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/da74850bff697576e0deef4eac05334c321d1d7f))



## [1.3.5](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.3.4...v1.3.5) (2020-04-30)


### Bug Fixes

* **product_mapper:** pull dimensions into the wrapper product from the default ([0d5a557](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/0d5a55790742aa8b109b17e7979e00e1612bb69e))



## [1.3.4](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.3.3...v1.3.4) (2020-04-30)



## [1.3.3](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.3.2...v1.3.3) (2020-04-30)



## [1.3.2](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.3.1...v1.3.2) (2020-04-30)



## [1.3.1](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.3.0...v1.3.1) (2020-04-24)



# [1.3.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.2.0...v1.3.0) (2020-04-14)


### Features

* **BigcommerceProductAgent:** enable product creation as Variants ([f20f9bc](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/f20f9bc0d2a4b61d3c498d09524771b0fef02b41))



# [1.2.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.1.0...v1.2.0) (2020-03-31)



# [1.1.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.0.2...v1.1.0) (2020-03-16)


### Features

* **client/*,agent,mapper/*:** Add support for metafields ([eefa215](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/eefa21597a5c9e762ff8a5d2731da92be5164ace))



## [1.0.2](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.0.1...v1.0.2) (2020-03-06)


### Bug Fixes

* **Client::Product:** fix issue with product updates ([e0c60ff](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/e0c60ff0f3ee612bffc0feb4fa0ff1d6e23495b5))



## [1.0.1](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/v1.0.0...v1.0.1) (2020-03-06)



# [1.0.0](https://github.com/5-stones/huginn_bigcommerce_product_agent/compare/890428ed1d776c539186d082f585949faa35a152...v1.0.0) (2020-03-06)


### Bug Fixes

* **package.json:** fix incorrect gemspec name in build script ([e8f4895](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/e8f4895ada03d01927152c0318b85e9fc2c1fbc1))


### Features

* ***/*:** add basic functionality to upsert an abstract product data structure to BigCommerce ([890428e](https://github.com/5-stones/huginn_bigcommerce_product_agent/commit/890428ed1d776c539186d082f585949faa35a152))



